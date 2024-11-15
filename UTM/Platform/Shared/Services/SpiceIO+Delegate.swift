//
//  SpiceIO+Delegate.swift
//  UTMKit
//
//  Created by Christophe Bronner on 2024-11-15.
//

import Foundation
import CocoaSpice

@objc public protocol UTMSpiceIODelegate: NSObjectProtocol {

	func spiceDidCreateInput(_ input: CSInput)

	func spiceDidDestroyInput(_ input: CSInput)

	func spiceDidCreateDisplay(_ display: CSDisplay)

	func spiceDidDestroyDisplay(_ display: CSDisplay)

	func spiceDidUpdateDisplay(_ display: CSDisplay)

	func spiceDidCreateSerial(_ serial: CSPort)

	func spiceDidDestroySerial(_ serial: CSPort)

	func spiceDidChangeUsbManager(_ manager: CSUSBManager?)

    @objc optional func spiceDynamicResolutionSupportDidChange(_ supported: Bool)

    @objc optional func spiceDidDisconnect()

}
