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
import CoreUTM

@available(iOS 13.4, *)
extension VMDisplayMetalViewController {

    // MARK: - GCMouse

    func startGCMouse() {
        if #available(iOS 14.0, *) {  // if iOS 14.0 or above, use GCMouse instead
            NotificationCenter.default.addObserver(self, selector: #selector(mouseDidBecomeCurrent(_:)), name: GCMouse.didBecomeCurrentNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(mouseDidStopBeingCurrent(_:)), name: GCMouse.didStopBeingCurrentNotification, object: nil)

            if let currentMouse = GCMouse.current {
                // Send the current mouse if already connected
                NotificationCenter.default.post(name: GCMouse.didBecomeCurrentNotification, object: currentMouse)
            }
        }
    }

    func stopGCMouse() {
        if let currentMouse = GCMouse.current {
            NotificationCenter.default.removeObserver(self, name: GCMouse.didBecomeCurrentNotification, object: nil)
            NotificationCenter.default.post(name: GCMouse.didStopBeingCurrentNotification, object: currentMouse)
        }
        NotificationCenter.default.removeObserver(self, name: GCMouse.didStopBeingCurrentNotification, object: nil)
    }

    @objc func mouseDidBecomeCurrent(_ notification: Notification) {
        guard let mouse = notification.object as? GCMouse else {
            UTMLog("invalid mouse object!")
            return
        }

        UTMLog("mouseDidBecomeCurrent: \(mouse)")

        mouse.mouseInput.mouseMovedHandler = { (mouse, deltaX, deltaY) in
            self.switchMouseType(.relative)
            self.vmInput.sendMouseMotion(self.mouseButtonDown, relativePoint: CGPoint(x: deltaX, y: -deltaY))
        }

        mouse.mouseInput.leftButton.pressedChangedHandler = { (button, value, pressed) in
            self.mouseLeftDown = pressed
            self.vmInput.sendMouseButton(kCSInputButtonLeft, pressed: pressed)
        }

        mouse.mouseInput.rightButton.pressedChangedHandler = { (button, value, pressed) in
            self.mouseRightDown = pressed
            self.vmInput.sendMouseButton(kCSInputButtonRight, pressed: pressed)
        }

        mouse.mouseInput.middleButton.pressedChangedHandler = { (button, value, pressed) in
            self.mouseMiddleDown = pressed
            self.vmInput.sendMouseButton(kCSInputButtonMiddle, pressed: pressed)
        }

        for i in 0..<min(4, mouse.mouseInput.auxiliaryButtons.count) {
            mouse.mouseInput.auxiliaryButtons[i].pressedChangedHandler = { (button, value, pressed) in
                switch i {
                case 0:
                    self.vmInput.sendMouseButton(kCSInputButtonUp, pressed: pressed)
                case 1:
                    self.vmInput.sendMouseButton(kCSInputButtonDown, pressed: pressed)
                case 2:
                    self.vmInput.sendMouseButton(kCSInputButtonSide, pressed: pressed)
                case 3:
                    self.vmInput.sendMouseButton(kCSInputButtonExtra, pressed: pressed)
                default:
                    break
                }
            }
        }
    }

    @objc func mouseDidStopBeingCurrent(_ notification: Notification) {
        guard let mouse = notification.object as? GCMouse else { return }

        UTMLog("mouseDidStopBeingCurrent: \(mouse)")

        mouse.mouseInput.mouseMovedHandler = nil
        mouse.mouseInput.leftButton.pressedChangedHandler = nil
        mouse.mouseInput.rightButton.pressedChangedHandler = nil
        mouse.mouseInput.middleButton.pressedChangedHandler = nil
        for i in 0..<min(4, mouse.mouseInput.auxiliaryButtons.count) {
            mouse.mouseInput.auxiliaryButtons[i].pressedChangedHandler = nil
        }
    }

    // MARK: - UIPointerInteractionDelegate

    // Add pointer interaction to VM view
    func initPointerInteraction() {
        mtkView.addInteraction(UIPointerInteraction(delegate: self))

        if #available(iOS 13.4, *) {
            let scroll = UIPanGestureRecognizer(target: self, action: #selector(gestureScroll(_:)))
            scroll.allowedScrollTypesMask = .all
            scroll.minimumNumberOfTouches = 0
            scroll.maximumNumberOfTouches = 0
            mtkView.addGestureRecognizer(scroll)
        }
    }

    var hasTouchpadPointer: Bool {
        return !delegate.qemuInputLegacy && !vmInput.serverModeCursor && indirectMouseType != .relative
    }

    func pointerInteraction(_ interaction: UIPointerInteraction, styleForRegion region: UIPointerRegion) -> UIPointerStyle? {
        // Hide cursor while hovering in VM view
        if interaction.view == mtkView && hasTouchpadPointer {
            #if TARGET_OS_VISION
            return nil  // FIXME: hidden pointer seems to jump around due to following gaze
            #else
            return UIPointerStyle.hiddenPointerStyle
            #endif
        }
        return nil
    }

    func isPointOnVMDisplay(_ pos: CGPoint) -> Bool {
        let screenSize = mtkView.drawableSize
        let scaledSize = CGSize(
            width: vmDisplay.displaySize.width * vmDisplay.viewportScale,
            height: vmDisplay.displaySize.height * vmDisplay.viewportScale
        )

        let drawRect = CGRect(
            x: vmDisplay.viewportOrigin.x + screenSize.width / 2 - scaledSize.width / 2,
            y: vmDisplay.viewportOrigin.y + screenSize.height / 2 - scaledSize.height / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )

        var translated = pos
        translated.x -= drawRect.origin.x
        translated.y -= drawRect.origin.y

        return 0 <= translated.x && translated.x <= scaledSize.width && 0 <= translated.y && translated.y <= scaledSize.height
    }

    func pointerInteraction(_ interaction: UIPointerInteraction, regionForRequest request: UIPointerRegionRequest, defaultRegion: UIPointerRegion) -> UIPointerRegion? {
        #if !TARGET_OS_VISION
        if #available(iOS 14.0, *) {
            if prefersPointerLocked {
                return nil
            }
        }
        #endif

        // Requesting region for the VM display?
        if interaction.view == mtkView && hasTouchpadPointer {
            let location = mtkView.convert(request.location, from: nil)
            var translated = location
            translated.x = CGPointToPixel(translated.x)
            translated.y = CGPointToPixel(translated.y)

            if isPointOnVMDisplay(translated) {
                // Move VM cursor, hide iOS cursor
                cursor.updateMovement(location)
                return UIPointerRegion(rect: mtkView.bounds, identifier: "vm view")
            } else {
                // Don't move VM cursor, show iOS cursor
                return nil
            }
        } else {
            return nil
        }
    }

    // MARK: - Scroll Gesture

    @IBAction func gestureScroll(_ sender: UIPanGestureRecognizer) {
        scrollWithInertia(sender)
    }
}

