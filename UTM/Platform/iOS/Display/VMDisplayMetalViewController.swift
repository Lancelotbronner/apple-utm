//
// Copyright © 2025 osy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import UIKit
import GameController
import CocoaSpice
import CoreUTM

final class VMDisplayMetalViewController: VMDisplayViewController, VMKeyboardViewDelegate {

    @IBOutlet weak var inputAccessoryView: UIInputView!
    @IBOutlet var customKeyModifierButtons: [VMKeyboardButton]!

    @IBOutlet var mtkView: CSMTKView!
    @IBOutlet var keyboardView: VMKeyboardView!

    var vmInput: CSInput?
    var vmDisplay: CSDisplay!

    var serverModeCursor: Bool {
        return vmInput?.serverModeCursor ?? false
    }

    var mutableKeyCommands = [UIKeyCommand]()

    var isDynamicResolutionSupported: Bool = false

    private var renderer: CSMetalRenderer?
    private var debounceResize: Any?
    private var cancelResize: Any?
    private var ignoreNextResize: Bool = false

    private var cursor: VMCursor?
    private var scroll: VMScroll?

    private var swipeUp: UISwipeGestureRecognizer?
    private var swipeDown: UISwipeGestureRecognizer?
    private var swipeScrollUp: UISwipeGestureRecognizer?
    private var swipeScrollDown: UISwipeGestureRecognizer?
    private var pan: UIPanGestureRecognizer?
    private var twoPan: UIPanGestureRecognizer?
    private var threePan: UIPanGestureRecognizer?
    private var tap: UITapGestureRecognizer?
    private var tapPencil: UITapGestureRecognizer?
    private var twoTap: UITapGestureRecognizer?
    private var longPress: UILongPressGestureRecognizer?
    private var pinch: UIPinchGestureRecognizer?

    private var controller: GCController?

    private var clickFeedbackGenerator: UISelectionFeedbackGenerator?

    init(display: CSDisplay, input: CSInput?) {
        super.init(nibName: nil, bundle: nil)
        self.vmDisplay = display
        self.vmInput = input
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        self.keyboardView = VMKeyboardView(frame: .zero)
        self.mtkView = CSMTKView(frame: .zero)
        self.keyboardView.delegate = self
        self.view.insertSubview(self.keyboardView, at: 0)
        self.view.insertSubview(self.mtkView, at: 1)
        self.mtkView.bindFrameToSuperviewBounds()
        loadInputAccessory()
    }

    func loadInputAccessory() {
        guard let nib = UINib(nibName: "VMDisplayMetalViewInputAccessory", bundle: nil) else { return }
        nib.instantiate(withOwner: self, options: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up software keyboard
        self.keyboardView.inputAccessoryView = self.inputAccessoryView

        // Set the view to use the default device
        self.mtkView.frame = self.view.bounds
        self.mtkView.device = MTLCreateSystemDefaultDevice()

        if self.mtkView.device == nil {
            UTMLog("Metal is not supported on this device")
            return
        }

        self.renderer = CSMetalRenderer(metalKitView: self.mtkView)
        if self.renderer == nil {
            UTMLog("Renderer failed initialization")
            return
        }

        // Initialize renderer with the view size
        if let fpsLimit = integerForSetting("QEMURendererFPSLimit"), fpsLimit > 0 {
            self.mtkView.preferredFramesPerSecond = fpsLimit
        }

        self.renderer?.changeUpscaler(self.delegate?.qemuDisplayUpscaler, downscaler: self.delegate?.qemuDisplayDownscaler)
        self.mtkView.delegate = self.renderer

        initTouch()
        initGamepad()

        if #available(iOS 13.4, *), NSClassFromString("UIPointerInteraction") != nil {
            initPointerInteraction()
        }

        if #available(iOS 12.1, *) {
            initPencilInteraction()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.prefersHomeIndicatorAutoHidden = true
#if !TARGET_OS_VISION
        startGCMouse()
#endif
        self.vmDisplay.addRenderer(self.renderer)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
#if !TARGET_OS_VISION
        stopGCMouse()
#endif
        self.vmDisplay.removeRenderer(self.renderer)
        removeObserver(self, forKeyPath: "vmDisplay.displaySize")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.delegate?.displayViewSize = convertSizeToNative(self.view.bounds.size)
        addObserver(self, forKeyPath: "vmDisplay.displaySize", options: [.new, .initial], context: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { _ in
            self.delegate?.displayViewSize = self.convertSizeToNative(size)
            self.delegate?.display(self.vmDisplay, didResizeTo: self.vmDisplay.displaySize)
            if self.delegate?.qemuDisplayIsDynamicResolution == true, self.isDynamicResolutionSupported {
                if size != self.vmDisplay.displaySize {
                    self.requestResolutionChange(toSize: size)
                }
            }
        }
    }

    func enterSuspended(isBusy: Bool) {
        super.enterSuspended(isBusy: isBusy)
        self.prefersPointerLocked = false
        self.view.window?.isIndirectPointerTouchIgnored = false
        if !isBusy {
            if self.delegate?.qemuHasClipboardSharing == true {
                UTMPasteboard.general.releasePollingMode(forObject: self)
            }
        }
    }

    func enterLive() {
        super.enterLive()
        self.prefersPointerLocked = true
        self.view.window?.isIndirectPointerTouchIgnored = true
        if self.delegate?.qemuDisplayIsDynamicResolution == true, self.isDynamicResolutionSupported {
            requestResolutionChange(toSize: self.view.bounds.size)
        }
        if self.delegate?.qemuHasClipboardSharing == true {
            UTMPasteboard.general.requestPollingMode(forObject: self)
        }
    }

    // MARK: - Key handling

    func showKeyboard() {
        super.showKeyboard()
        self.keyboardView.becomeFirstResponder()
    }

    func hideKeyboard() {
        super.hideKeyboard()
        self.keyboardView.resignFirstResponder()
    }

    func sendExtendedKey(type: CSInputKey, code: Int) {
        var modifiedCode = code
        if (code & 0xFF00) == 0xE000 {
            modifiedCode = 0x100 | (code & 0xFF)
        } else if code >= 0x100 {
            UTMLog("warning: ignored invalid keycode 0x\(String(format: "%x", code))")
        }
        vmInput?.sendKey(type: type, code: modifiedCode)
    }

    // MARK: - Resizing

    func convertSizeToNative(_ size: CGSize) -> CGSize {
        if delegate?.qemuDisplayIsNativeResolution == true {
            return CGSize(width: CGPointToPixel(size.width), height: CGPointToPixel(size.height))
        }
        return size
    }

    func requestResolutionChange(toSize size: CGSize) {
        debounceResize = debounce(kResizeDebounceSecs, context: debounceResize) {
            UTMLog("DISPLAY: requesting resolution (\(size.width), \(size.height))")
            var newSize = self.convertSizeToNative(size)
            self.debounceResize = nil

#if TARGET_OS_VISION
            self.cancelResize = debounce(kResizeTimeoutSecs, context: self.cancelResize) {
                self.cancelResize = nil
                UTMLog("DISPLAY: requesting resolution cancelled")
                self.resizeWindowToDisplaySize()
            }
#endif
            self.vmDisplay.requestResolution(CGRect(origin: .zero, size: newSize))
        }
    }

    func resizeWindowToDisplaySize() {
        let displaySize = vmDisplay.displaySize
        UTMLog("DISPLAY: request window resize to (\(displaySize.width), \(displaySize.height))")

#if TARGET_OS_VISION
        var minSize = displaySize
        if delegate?.qemuDisplayIsNativeResolution == true {
            minSize.width = CGPixelToPoint(minSize.width)
            minSize.height = CGPixelToPoint(minSize.height)
        }
        let maxSize = CGSize(width: UIProposedSceneSizeNoPreference, height: UIProposedSceneSizeNoPreference)
        let geoPref = UIWindowSceneGeometryPreferencesVision(size: minSize)
        geoPref.minimumSize = CGSize(width: 800, height: 600)
        geoPref.maximumSize = maxSize
        geoPref.resizingRestrictions = UIWindowSceneResizingRestrictionsFreeform

        DispatchQueue.main.async {
            if self.view.bounds.size == minSize {
                self.delegate?.displayViewSize = self.convertSizeToNative(self.view.bounds.size)
                self.delegate?.display(self.vmDisplay, didResizeTo: displaySize)
            }
            self.view.window?.windowScene.requestGeometryUpdate(withPreferences: geoPref, errorHandler: nil)
        }
#else
        if displaySize == CGSize.zero { return }
        delegate?.display(self.vmDisplay, didResizeTo: displaySize)
#endif
    }
}
