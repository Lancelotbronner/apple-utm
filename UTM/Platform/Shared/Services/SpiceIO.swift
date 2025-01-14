//
//  SpiceIO.swift
//  UTMKit
//
//  Created by Christophe Bronner on 2024-11-15.
//

import Foundation
import CoreUTM
import QEMUKitInternal
import CocoaSpice

/// Options for initializing UTMSpiceIO
public struct UTMSpiceIOOptions : OptionSet, Sendable {
    public var rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let hasAudio = Self(rawValue: 0x1)

    public static let hasClipboardSharing = Self(rawValue: 0x2)

    public static let isShareReadOnly = Self(rawValue: 0x4)

    public static let hasDebugLog = Self(rawValue: 0x8)
}

public final class UTMSpiceIO : NSObject, QEMUInterface {
    public var primaryDisplay: CSDisplay?
    public var primaryInput: CSInput?
    public var primarySerial: CSPort?
    public var connectDelegate: (any QEMUInterfaceConnectDelegate)?

#if WITH_USB
    public var primaryUsbManager: CSUSBManager?
#endif

    public weak var delegate: (any UTMSpiceIODelegate)? {
        didSet { didSetDelegate() }
    }

    public private(set) var displays: Set<CSDisplay> = []
    public private(set) var serials: Set<CSPort> = []

    private let parameters: Parameters
    private let options: UTMSpiceIOOptions
    private var spiceConnection: CSConnection?
    private var spice: CSMain?
    private var sharedDirectory: URL?
    private var isConnected = false

    private var dynamicResolutionSupported = false {
        didSet { didSetDynamicResolutionSupported(oldValue) }
    }

    private enum Parameters {
        case socket(URL)
        case tls(host: String, port: Int, publicKey: Data, password: String?)
    }

    public init(socketUrl: URL, options: UTMSpiceIOOptions = []) {
        parameters = .socket(socketUrl)
        self.options = options;
    }

    public init(host: String, tlsPort: Int, serverPublicKey: Data, password: String, options: UTMSpiceIOOptions = []) {
        parameters = .tls(host: host, port: tlsPort, publicKey: serverPublicKey, password: password)
        self.options = options;
    }

    public var logHandler: LogHandler_t? {
        get { CSMain.shared.logHandler }
        set { CSMain.shared.logHandler = newValue }
    }

    public func start() throws {
        spice = spice ?? CSMain.shared
        guard let spice else { return }

        if options.contains(.hasDebugLog) {
            spice.spiceSetDebug(true)
        }

        // do not need to encode/decode audio locally
        setenv("SPICE_DISABLE_OPUS", "1", 1);

        if case let .socket(url) = parameters {
            // need to chdir to workaround AF_UNIX sun_len limitations
            let curdir = url.deletingLastPathComponent().path
            if !FileManager.default.changeCurrentDirectoryPath(curdir) {
                throw NSError(domain: kUTMErrorDomain, code: -1, userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString("Failed to change current directory.", comment: "UTMSpiceIO")
                ])
            }
            return
        }

        if !spice.spiceStart() {
            throw NSError(domain: kUTMErrorDomain, code: -1, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Failed to start SPICE client.", comment: "UTMSpiceIO")
            ])
        }

        initializeSpiceIfNeeded()
    }

    public func connect() throws {
        guard spiceConnection?.connect() == false else { return }
        throw NSError(domain: kUTMErrorDomain, code: -1, userInfo: [
            NSLocalizedDescriptionKey: NSLocalizedString("Internal error trying to connect to SPICE server.", comment: "UTMSpiceIO")
        ])
    }

    public func disconnect() {
        endSharingDirectory()
        if let spiceConnection {
            spiceConnection.disconnect()
            spiceConnection.delegate = nil;
            self.spiceConnection = nil;
        }
        spice = nil;
        primaryDisplay = nil;
        displays.removeAll(keepingCapacity: true)
        primaryInput = nil;
        primarySerial = nil;
        serials.removeAll(keepingCapacity: true)
#if WITH_USB
        primaryUsbManager = nil;
#endif
    }

    public func screenshot() async -> CSScreenshot? {
        guard let primaryDisplay else { return nil }
        return await primaryDisplay.screenshot()
    }
}

extension UTMSpiceIO {

    private func initializeSpiceIfNeeded() {
        guard spiceConnection == nil else { return }
        let spiceConnection: CSConnection
        switch parameters {
        case let .socket(url):
            let relativeSocketFile = URL(fileURLWithPath: url.lastPathComponent)
            spiceConnection = CSConnection(unixSocketFile: relativeSocketFile)

        case let .tls(host, port, publicKey, password):
            spiceConnection = CSConnection(host: host, tlsPort: port.description, serverPublicKey: publicKey)
            spiceConnection.password = password
        }

        spiceConnection.delegate = self;
        spiceConnection.audioEnabled = options.contains(.hasAudio)
        spiceConnection.session.shareClipboard = options.contains(.hasClipboardSharing)
        spiceConnection.session.pasteboardDelegate = UTMPasteboard.general
        self.spiceConnection = spiceConnection
    }

}

extension UTMSpiceIO: CSConnectionDelegate {

    private func assert(connection: CSConnection) {
        Swift.assert(connection == spiceConnection, "Unknown connection")
    }

    public func spiceConnected(_ connection: CSConnection) {
        assert(connection: connection)
        isConnected = true;
#if WITH_USB
        primaryUsbManager = connection.usbManager;
        delegate?.spiceDidChangeUsbManager(connection.usbManager)
#endif
#if WITH_REMOTE
        connectDelegate.remoteInterfaceDidConnect(self)
#endif
    }

    public func spiceDisconnected(_ connection: CSConnection) {
        assert(connection: connection)
        isConnected = false;
        delegate?.spiceDidDisconnect?()
    }

    public func spiceInputAvailable(_ connection: CSConnection, input: CSInput) {
        primaryInput = primaryInput ?? input
        delegate?.spiceDidCreateInput(input)
    }

    public func spiceInputUnavailable(_ connection: CSConnection, input: CSInput) {
        if primaryInput == input {
            primaryInput = nil
        }
        delegate?.spiceDidDestroyInput(input)
    }

    public func spiceError(_ connection: CSConnection, code: CSConnectionError, message: String?) {
        assert(connection: connection)
        isConnected = false;
#if WITH_REMOTE
        connectDelegate.remoteInterface(self, didErrorWithMessage: message ?? "")
#else
        connectDelegate?.qemuInterface(self, didErrorWithMessage: message ?? "")
#endif
    }

    public func spiceDisplayCreated(_ connection: CSConnection, display: CSDisplay) {
        assert(connection: connection)
        if display.isPrimaryDisplay {
            primaryDisplay = display
        }
        displays.insert(display)
        delegate?.spiceDidCreateDisplay(display)
    }

    public func spiceDisplayUpdated(_ connection: CSConnection, display: CSDisplay) {
        assert(connection: connection)
        delegate?.spiceDidUpdateDisplay(display)
    }

    public func spiceDisplayDestroyed(_ connection: CSConnection, display: CSDisplay) {
        assert(connection: connection)
        displays.remove(display)
        if primaryDisplay == display {
            primaryDisplay = nil
        }
        delegate?.spiceDidDestroyDisplay(display)
    }

    public func spiceAgentConnected(_ connection: CSConnection, supportingFeatures features: CSConnectionAgentFeature) {
        dynamicResolutionSupported = features.contains(.monitorsConfig)
    }

    public func spiceAgentDisconnected(_ connection: CSConnection) {
        dynamicResolutionSupported = false;
    }

    public func spiceForwardedPortOpened(_ connection: CSConnection, port: CSPort) {
        guard let name = port.name else { return }
#if WITH_REMOTE
        switch name {
        case "org.qemu.monitor.qmp.0":
            let qemuPort = UTMQemuPort(from: port)
            connectDelegate.qemuInterface(self, didCreateMonitorPort: qemuPort)

        case "org.qemu.guest_agent.0":
            let qemuPort = UTMQemuPort(from: port)
            connectDelegate.qemuInterface(self, didCreateGuestAgentPort: qemuPort)

        default: break
        }
#endif
        switch name {
        case "com.utmapp.terminal.0":
            primarySerial = port

        default: break
        }

        if name.hasPrefix("com.utmapp.terminal.") {
            serials.insert(port)
            delegate?.spiceDidCreateSerial(port)
        }
    }

    public func spiceForwardedPortClosed(_ connection: CSConnection, port: CSPort) {
        guard let name = port.name else { return }
        switch name {
        case "org.qemu.monitor.qmp.0": break
        case "org.qemu.guest_agent.0": break
        default: break
        }

        if name.hasPrefix("com.utmapp.terminal.") {
            serials.remove(port)
            if primarySerial == port {
                primarySerial = nil
            }
            delegate?.spiceDidDestroySerial(port)
        }
    }

}

//MARK: - Shared Directory

extension UTMSpiceIO {

    public func changeSharedDirectory(_ url: URL) {
        if sharedDirectory != nil {
            endSharingDirectory()
        }
        sharedDirectory = url
        startSharingDirectory()
    }

    private func startSharingDirectory() {
        guard let spiceConnection, let sharedDirectory else { return }
        UTMLogging.sharedInstance().writeLine("setting share directory to \(sharedDirectory.path)")
        _ = sharedDirectory.startAccessingSecurityScopedResource()
        spiceConnection.session.setSharedDirectory(sharedDirectory.path, readOnly: options.contains(.isShareReadOnly))
    }

    private func endSharingDirectory() {
        guard let sharedDirectory else { return }
        sharedDirectory.stopAccessingSecurityScopedResource()
        self.sharedDirectory = nil
        UTMLogging.sharedInstance().writeLine("ended share directory sharing")
    }

}

//MARK: - Property Observers

extension UTMSpiceIO {

    private func didSetDelegate() {
        // make sure to send initial data
        if let primaryInput {
            delegate?.spiceDidCreateInput(primaryInput)
        }
        if let primaryDisplay {
            delegate?.spiceDidCreateDisplay(primaryDisplay)
        }
        if let primarySerial {
            delegate?.spiceDidCreateSerial(primarySerial)
        }
#if WITH_USB
        if let primaryUsbManager {
            delegate?.spiceDidChangeUsbManager(primaryUsbManager)
        }
#endif
        delegate?.spiceDynamicResolutionSupportDidChange?(dynamicResolutionSupported)
        for display in displays where display != primaryDisplay {
            delegate?.spiceDidCreateDisplay(display)
        }
        for port in serials where port != primarySerial {
            delegate?.spiceDidCreateSerial(port)
        }
    }

    private func didSetDynamicResolutionSupported(_ oldValue: Bool) {
        guard dynamicResolutionSupported != oldValue else { return }
        delegate?.spiceDynamicResolutionSupportDidChange?(dynamicResolutionSupported)
    }

}
