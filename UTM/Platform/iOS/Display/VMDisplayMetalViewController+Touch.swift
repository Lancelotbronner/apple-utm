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

import CoreUTM
import UIKit

// Constants
let kScrollSpeedReduction: CGFloat = 100.0
let kCursorResistance: CGFloat = 50.0
let kScrollResistance: CGFloat = 10.0

extension VMDisplayMetalViewController {

    // Gesture initialization
    func initTouch() {
        // Mouse cursor
        cursor = VMCursor(vmViewController: self)
        scroll = VMScroll(vmViewController: self)

#if targetEnvironment(simulator) || !targetEnvironment(vision)
        // Setup gesture recognizers for non-visionOS (standard iOS)
        swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(gestureSwipeUp(_:)))
        swipeUp.numberOfTouchesRequired = 3
        swipeUp.direction = .up
        swipeUp.delegate = self

        swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(gestureSwipeDown(_:)))
        swipeDown.numberOfTouchesRequired = 3
        swipeDown.direction = .down
        swipeDown.delegate = self

        swipeScrollUp = UISwipeGestureRecognizer(target: self, action: #selector(gestureSwipeScroll(_:)))
        swipeScrollUp.numberOfTouchesRequired = 2
        swipeScrollUp.direction = .up
        swipeScrollUp.delegate = self

        swipeScrollDown = UISwipeGestureRecognizer(target: self, action: #selector(gestureSwipeScroll(_:)))
        swipeScrollDown.numberOfTouchesRequired = 2
        swipeScrollDown.direction = .down
        swipeScrollDown.delegate = self

        pan = UIPanGestureRecognizer(target: self, action: #selector(gesturePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        pan.delegate = self

        twoPan = UIPanGestureRecognizer(target: self, action: #selector(gestureTwoPan(_:)))
        twoPan.minimumNumberOfTouches = 2
        twoPan.maximumNumberOfTouches = 2
        twoPan.delegate = self

        threePan = UIPanGestureRecognizer(target: self, action: #selector(gestureThreePan(_:)))
        threePan.minimumNumberOfTouches = 3
        threePan.maximumNumberOfTouches = 3
        threePan.delegate = self

        tap = UITapGestureRecognizer(target: self, action: #selector(gestureTap(_:)))
        tap.delegate = self
        tap.allowedTouchTypes = [.direct]

        twoTap = UITapGestureRecognizer(target: self, action: #selector(gestureTwoTap(_:)))
        twoTap.numberOfTouchesRequired = 2
        twoTap.delegate = self
        twoTap.allowedTouchTypes = [.direct]

        longPress = UILongPressGestureRecognizer(target: self, action: #selector(gestureLongPress(_:)))
        longPress.delegate = self
        longPress.allowedTouchTypes = [.direct]

        pinch = UIPinchGestureRecognizer(target: self, action: #selector(gesturePinch(_:)))
        pinch.delegate = self

        // Add gestures to the view
        mtkView.addGestureRecognizer(swipeUp)
        mtkView.addGestureRecognizer(swipeDown)
        mtkView.addGestureRecognizer(swipeScrollUp)
        mtkView.addGestureRecognizer(swipeScrollDown)
        mtkView.addGestureRecognizer(pan)
        mtkView.addGestureRecognizer(twoPan)
        mtkView.addGestureRecognizer(threePan)
        mtkView.addGestureRecognizer(tap)
        mtkView.addGestureRecognizer(twoTap)
        mtkView.addGestureRecognizer(longPress)
        mtkView.addGestureRecognizer(pinch)

        // Feedback generator for clicks
        clickFeedbackGenerator = UISelectionFeedbackGenerator()
#endif
    }

    // Properties from settings
    var isInvertScroll: Bool {
        return boolForSetting("InvertScroll")
    }

    func gestureType(forSetting key: String) -> VMGestureType {
        let integer = integerForSetting(key)
        if integer < VMGestureType.none.rawValue || integer >= VMGestureType.max.rawValue {
            return .none
        } else {
            return VMGestureType(rawValue: integer) ?? .none
        }
    }

    var longPressType: VMGestureType {
        return gestureType(forSetting: "GestureLongPress")
    }

    var twoFingerTapType: VMGestureType {
        return gestureType(forSetting: "GestureTwoTap")
    }

    var twoFingerPanType: VMGestureType {
        return gestureType(forSetting: "GestureTwoPan")
    }

    var twoFingerScrollType: VMGestureType {
        return gestureType(forSetting: "GestureTwoScroll")
    }

    var threeFingerPanType: VMGestureType {
        return gestureType(forSetting: "GestureThreePan")
    }

    func mouseType(forSetting key: String) -> VMMouseType {
        let integer = integerForSetting(key)
        if integer < VMMouseType.relative.rawValue || integer >= VMMouseType.max.rawValue {
            return .relative
        } else {
            return VMMouseType(rawValue: integer) ?? .relative
        }
    }

    var touchMouseType: VMMouseType {
        return mouseType(forSetting: "MouseTouchType")
    }

    var pencilMouseType: VMMouseType {
        return mouseType(forSetting: "MousePencilType")
    }

    var indirectMouseType: VMMouseType {
#if targetEnvironment(vision)
        return .absolute
#else
        if #available(iOS 14.0, *) {
            return .relative
        } else {
            return .absolute // Legacy iOS 13.4 mouse handling requires absolute
        }
#endif
    }

    // Converting view points to VM display points
    private func clipRectToBounds(_ rect1: CGRect, rect2: CGRect) -> CGRect {
        var rect2 = rect2
        if rect2.origin.x < rect1.origin.x {
            rect2.origin.x = rect1.origin.x
        } else if rect2.origin.x + rect2.size.width > rect1.origin.x + rect1.size.width {
            rect2.origin.x = rect1.origin.x + rect1.size.width - rect2.size.width
        }

        if rect2.origin.y < rect1.origin.y {
            rect2.origin.y = rect1.origin.y
        } else if rect2.origin.y + rect2.size.height > rect1.origin.y + rect1.size.height {
            rect2.origin.y = rect1.origin.y + rect1.size.height - rect2.size.height
        }
        return rect2
    }

    func clipCursorToDisplay(_ pos: CGPoint) -> CGPoint {
        let screenSize = mtkView.drawableSize
        let scaledSize = CGSize(width: vmDisplay.displaySize.width * vmDisplay.viewportScale,
                                height: vmDisplay.displaySize.height * vmDisplay.viewportScale)
        var drawRect = CGRect(
            x: vmDisplay.viewportOrigin.x + screenSize.width / 2 - scaledSize.width / 2,
            y: vmDisplay.viewportOrigin.y + screenSize.height / 2 - scaledSize.height / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
        var clippedPos = pos
        clippedPos.x -= drawRect.origin.x
        clippedPos.y -= drawRect.origin.y

        if clippedPos.x < 0 {
            clippedPos.x = 0
        } else if clippedPos.x > scaledSize.width {
            clippedPos.x = scaledSize.width
        }

        if clippedPos.y < 0 {
            clippedPos.y = 0
        } else if clippedPos.y > scaledSize.height {
            clippedPos.y = scaledSize.height
        }

        clippedPos.x /= vmDisplay.viewportScale
        clippedPos.y /= vmDisplay.viewportScale
        return clippedPos
    }

    func clipDisplayToView(_ target: CGPoint) -> CGPoint {
        let screenSize = mtkView.drawableSize
        let scaledSize = CGSize(width: vmDisplay.displaySize.width * vmDisplay.viewportScale,
                                height: vmDisplay.displaySize.height * vmDisplay.viewportScale)

        var drawRect = CGRect(
            x: target.x + screenSize.width / 2 - scaledSize.width / 2,
            y: target.y + screenSize.height / 2 - scaledSize.height / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )

        var boundRect = CGRect(
            origin: CGPoint(
                x: screenSize.width - max(screenSize.width, scaledSize.width),
                y: screenSize.height - max(screenSize.height, scaledSize.height)
            ),
            size: CGSize(
                width: 2 * max(screenSize.width, scaledSize.width) - screenSize.width,
                height: 2 * max(screenSize.height, scaledSize.height) - screenSize.height
            )
        )

        let clippedRect = clipRectToBounds(boundRect, rect2: drawRect)
        return CGPoint(x: clippedRect.origin.x - (screenSize.width / 2 - scaledSize.width / 2),
                       y: clippedRect.origin.y - (screenSize.height / 2 - scaledSize.height / 2))
    }

    // Gesture methods (Simplified)
    @objc func moveMouseWithInertia(_ sender: UIPanGestureRecognizer) {
        let location = sender.location(in: sender.view)
        let velocity = sender.velocity(in: sender.view)

        if sender.state == .began {
            cursor.startMovement(location)
        }
        if sender.state != .cancelled {
            cursor.updateMovement(location)
        }
        if sender.state == .ended {
            cursor.endMovement(withVelocity: velocity, resistance: kCursorResistance)
        }
    }

    @objc func scrollWithInertia(_ sender: UIPanGestureRecognizer) {
        let location = sender.location(in: sender.view)
        let velocity = sender.velocity(in: sender.view)

        if sender.state == .began {
            scroll.startMovement(location)
        }
        if sender.state != .cancelled {
            scroll.updateMovement(location)
        }
        if sender.state == .ended {
            scroll.endMovement(withVelocity: velocity, resistance: kScrollResistance)
        }
    }

    @IBAction func gesturePan(_ sender: UIPanGestureRecognizer) {
        if serverModeCursor {
            // Otherwise we handle in touchesMoved
            moveMouseWithInertia(sender)
        }
    }

    func moveScreen(_ sender: UIPanGestureRecognizer) {
        if sender.state == .began {
            lastTwoPanOrigin = vmDisplay.viewportOrigin
        }

        if sender.state != .cancelled {
            let translation = sender.translation(in: sender.view)
            var viewport = vmDisplay.viewportOrigin
            viewport.x = CGPointToPixel(translation.x) + lastTwoPanOrigin.x
            viewport.y = CGPointToPixel(translation.y) + lastTwoPanOrigin.y
            vmDisplay.viewportOrigin = clipDisplayToView(viewport)
            // Persist this change in viewState
            delegate.displayOrigin = vmDisplay.viewportOrigin
        }

        if sender.state == .ended {
            // TODO: Decelerate
        }
    }

    @IBAction func gestureTwoPan(_ sender: UIPanGestureRecognizer) {
        switch twoFingerPanType {
        case .moveScreen:
            moveScreen(sender)
        case .dragCursor:
            dragCursor(sender.state, primary: true, secondary: false, middle: false)
            moveMouseWithInertia(sender)
        case .mouseWheel:
            scrollWithInertia(sender)
        default:
            break
        }
    }

    @IBAction func gestureThreePan(_ sender: UIPanGestureRecognizer) {
        switch threeFingerPanType {
        case .moveScreen:
            moveScreen(sender)
        case .dragCursor:
            dragCursor(sender.state, primary: true, secondary: false, middle: false)
            moveMouseWithInertia(sender)
        case .mouseWheel:
            scrollWithInertia(sender)
        default:
            break
        }
    }

    public func moveMouseAbsolute(_ location: CGPoint) -> CGPoint {
        var translated = location
        translated.x = CGPointToPixel(translated.x)
        translated.y = CGPointToPixel(translated.y)
        translated = clipCursorToDisplay(translated)

        if !vmInput.serverModeCursor {
            vmInput.sendMousePosition(mouseButtonDown, absolutePoint: translated)
            vmDisplay.cursor.moveTo(translated)
        } else {
            UTMLog("Warning: ignored mouse set (%f, %f) while mouse is in server mode", translated.x, translated.y)
        }

        return translated
    }

    public func moveMouseRelative(_ translation: CGPoint) -> CGPoint {
        var translation = translation
        translation.x = CGPointToPixel(translation.x) / vmDisplay.viewportScale
        translation.y = CGPointToPixel(translation.y) / vmDisplay.viewportScale

        if vmInput.serverModeCursor {
            vmInput.sendMouseMotion(mouseButtonDown, relativePoint: translation)
        } else {
            UTMLog("Warning: ignored mouse motion (%f, %f) while mouse is in client mode", translation.x, translation.y)
        }

        return translation
    }

    public func moveMouse(to newValue: CGPoint, from lastCenter: CGPoint, by speed: CGFloat) -> CGPoint {
        if serverModeCursor {
            let diff = CGPoint(
                x: (newValue.x - lastCenter.x) * speed,
                y: (newValue.y - lastCenter.y) * speed)
            return moveMouseRelative(diff)
        }
        return moveMouseAbsolute(newValue)
    }

    func moveMouseScroll(_ translation: CGPoint) -> CGPoint {
        var translation = translation
        translation.y = CGPointToPixel(translation.y) / kScrollSpeedReduction

        if isInvertScroll {
            translation.y = -translation.y
        }

        vmInput.sendMouseScroll(kCSInputScrollSmooth, button: mouseButtonDown, dy: translation.y)
        return translation
    }

    func mouseClick(_ button: CSInputButton, location: CGPoint) {
        if !serverModeCursor {
            cursor.center = location
        }

        vmInput.sendMouseButton(button, pressed: true)

        // Handle mouse release after a small delay
        onDelay(0.05) {
            self.mouseLeftDown = false
            self.mouseRightDown = false
            self.mouseMiddleDown = false
            self.vmInput.sendMouseButton(button, pressed: false)
        }

#if !targetEnvironment(vision)
        clickFeedbackGenerator.selectionChanged()
#endif
    }

    func dragCursor(_ state: UIGestureRecognizer.State, primary: Bool, secondary: Bool, middle: Bool) {
        if state == .began {
#if !targetEnvironment(vision)
            clickFeedbackGenerator.selectionChanged()
#endif
            if primary {
                mouseLeftDown = true
            }
            if secondary {
                mouseRightDown = true
            }
            if middle {
                mouseMiddleDown = true
            }
            vmInput.sendMouseButton(mouseButtonDown, pressed: true)
        } else if state == .ended {
            mouseLeftDown = false
            mouseRightDown = false
            mouseMiddleDown = false
            vmInput.sendMouseButton(mouseButtonDown, pressed: false)
        }
    }

    @IBAction func gestureTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended && serverModeCursor {
            // Otherwise we handle in touchesBegan
            mouseClick(.left, location: sender.location(in: sender.view))
        }
    }

    @IBAction func gestureTwoTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended && twoFingerTapType == .rightClick {
            mouseClick(.right, location: sender.location(in: sender.view))
        }
    }

    @IBAction func gestureLongPress(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .ended && longPressType == .rightClick {
            mouseClick(.right, location: sender.location(in: sender.view))
        } else if longPressType == .dragCursor {
            dragCursor(sender.state, primary: true, secondary: false, middle: false)
        }
    }

    @IBAction func gesturePinch(_ sender: UIPinchGestureRecognizer) {
        // Disable pinch if move screen on pan is disabled
        if twoFingerPanType != .moveScreen && threeFingerPanType != .moveScreen {
            return
        }

        if sender.state == .began || sender.state == .changed || sender.state == .ended {
            assert(sender.scale > 0, "sender.scale cannot be 0")
            var scaling: CGFloat

            if !delegate.qemuDisplayIsNativeResolution {
                // Undo in `setDisplayScaling:origin:`
                scaling = CGPixelToPoint(CGPointToPixel(delegate.displayScale) * sender.scale)
            } else {
                scaling = delegate.displayScale * sender.scale
            }
            delegate.displayScale = scaling
            sender.scale = 1.0
        }
    }

    @IBAction func gestureSwipeUp(_ sender: UISwipeGestureRecognizer) {
        if sender.state == .ended {
            showKeyboard()
        }
    }

    @IBAction func gestureSwipeDown(_ sender: UISwipeGestureRecognizer) {
        if sender.state == .ended {
            hideKeyboard()
        }
    }

    @IBAction func gestureSwipeScroll(_ sender: UISwipeGestureRecognizer) {
        if sender.state == .ended && twoFingerScrollType == .mouseWheel {
            if sender == swipeScrollUp {
                vmInput.sendMouseScroll(kCSInputScrollUp, button: mouseButtonDown, dy: 0)
            } else if sender == swipeScrollDown {
                vmInput.sendMouseScroll(kCSInputScrollDown, button: mouseButtonDown, dy: 0)
            } else {
                assert(false, "Invalid call to gestureSwipeScroll")
            }
        }
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == twoPan && (otherGestureRecognizer == swipeUp || otherGestureRecognizer == swipeDown) {
            return true
        }
        if gestureRecognizer == twoTap && (otherGestureRecognizer == swipeDown || otherGestureRecognizer == swipeUp) {
            return true
        }
        if gestureRecognizer == tap && otherGestureRecognizer == twoTap {
            return true
        }
        if gestureRecognizer == longPress && (otherGestureRecognizer == tap || otherGestureRecognizer == twoTap) {
            return true
        }
        if gestureRecognizer == pinch && (otherGestureRecognizer == swipeDown || otherGestureRecognizer == swipeUp) {
            return true
        }
        if gestureRecognizer == pan && (otherGestureRecognizer == swipeUp || otherGestureRecognizer == swipeDown) {
            return true
        }
        if gestureRecognizer == threePan && (otherGestureRecognizer == swipeUp || otherGestureRecognizer == swipeDown) {
            return true
        }

        // Only if we do not disable two-finger swipe
        if twoFingerScrollType != .none {
            if gestureRecognizer == twoPan && (otherGestureRecognizer == swipeScrollUp || otherGestureRecognizer == swipeScrollDown) {
                return true
            }
        }

#if !targetEnvironment(vision)
        return pencilGestureRecognizer(gestureRecognizer, shouldRequireFailureOf: otherGestureRecognizer)
#else
        return false
#endif
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == twoPan && otherGestureRecognizer == pinch {
            return twoFingerPanType == .moveScreen
        } else if gestureRecognizer == pan && otherGestureRecognizer == longPress {
            return true
        } else if twoFingerScrollType == .none && otherGestureRecognizer == twoPan {
            // If two-finger swipe is disabled, allow two-finger pans
            if gestureRecognizer == swipeScrollUp || gestureRecognizer == swipeScrollDown {
                return true
            } else {
                return false
            }
        }
        return false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool {
        if event.type == .transform {
            UTMLog("Ignoring UIEventTypeTransform")
            return false
        }
        return true
    }

    // MARK: - Touch Type

    func touchTypeToMouseType(_ type: UITouch.TouchType) -> VMMouseType {
        switch type {
        case .direct:
            return touchMouseType
        case .pencil:
            return pencilMouseType
        case .indirect:
            return indirectMouseType
            @available(iOS 13.4, *)
        case .indirectPointer:
            return indirectMouseType
        default:
            return touchMouseType // Compatibility with future values
        }
    }

    // MARK: - Helper Methods

    func showKeyboard() {
        // Show keyboard implementation
    }

    func hideKeyboard() {
        // Hide keyboard implementation
    }

    func pencilGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Handle pencil gesture recognition logic
        return false
    }

    // MARK: - Mouse Type Switching

    @discardableResult
    func switchMouseType(_ type: VMMouseType) -> Bool {
        let shouldHideCursor = (type == .absoluteHideCursor)
        let shouldUseServerMouse = (type == .relative)

        vmDisplay.cursor.isInhibited = shouldHideCursor

        if shouldUseServerMouse != vmInput.serverModeCursor {
            UTMLog("Switching mouse mode to server: \(shouldUseServerMouse) for type: \(type.rawValue)")
            delegate.requestInputTablet(!shouldUseServerMouse)
            return true
        }
        return false
    }

#if targetEnvironment(vision)
    func isTouchGazeGesture(_ touch: UITouch) -> Bool {
        if let manipulator = touch.value(forKey: "_manipulator") {
            let selector = NSSelectorFromString("_type")
            if manipulator.responds(to: selector) {
                let imp = manipulator.method(for: selector)
                if let imp = imp {
                    return (imp as! (AnyObject, Selector) -> Int)(manipulator, selector) == 2
                }
            }
        }
        return false
    }
#endif

    // MARK: - Touch Event Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !delegate.qemuInputLegacy {
            for touch in touches {
                var type = touchTypeToMouseType(touch.type)

#if targetEnvironment(vision)
                if isTouchGazeGesture(touch) {
                    type = .relative
                }
#endif

                if switchMouseType(type) {
                    dragCursor(state: .ended, primary: true, secondary: true, middle: true) // reset drag
                } else if !vmInput.serverModeCursor { // start click for client mode
                    var primary = true
                    var secondary = false
                    var middle = false

                    let pos = touch.location(in: mtkView)

                    // iOS 13.4+ Pointing device support
                    if #available(iOS 13.4, *) {
                        if touch.type == .indirectPointer {
                            primary = (event?.buttonMask.contains(.primary)) ?? false
                            secondary = (event?.buttonMask.contains(.secondary)) ?? false
                            middle = (event?.buttonMask.contains(.middle)) ?? false
                        }
                    }

                    // Apple Pencil 2 right-click mode (iOS 12.1+)
                    if #available(iOS 12.1, *) {
                        if pencilRightClickForTouch(touch) {
                            primary = false
                            secondary = true
                        }
                    }

                    cursor.startMovement(pos)
                    cursor.updateMovement(pos)
                    dragCursor(state: .began, primary: primary, secondary: secondary, middle: middle)
                }
                break // handle a single touch only
            }
        } else {
            switchMouseType(.relative)
        }
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Move cursor in client mode, in server mode we handle in gesturePan
        if !delegate.qemuInputLegacy && !vmInput.serverModeCursor {
            for touch in touches {
                cursor.updateMovement(touch.location(in: mtkView))
                break // handle single touch
            }
        }
        super.touchesMoved(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Release click in client mode, in server mode we handle in gesturePan
        if !delegate.qemuInputLegacy && !vmInput.serverModeCursor {
            dragCursor(state: .ended, primary: true, secondary: true, middle: true)
        }
        super.touchesCancelled(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Release click in client mode, in server mode we handle in gesturePan
        if !delegate.qemuInputLegacy && !vmInput.serverModeCursor {
            dragCursor(state: .ended, primary: true, secondary: true, middle: true)
        }
        super.touchesEnded(touches, with: event)
    }

    // MARK: - Helper Methods

    func touchTypeToMouseType(_ type: UITouch.TouchType) -> VMMouseType {
        switch type {
        case .direct:
            return touchMouseType
        case .pencil:
            return pencilMouseType
        case .indirect:
            return indirectMouseType
            @available(iOS 13.4, *)
        case .indirectPointer:
            return indirectMouseType
        default:
            return touchMouseType // Compatibility with future values
        }
    }

    func dragCursor(state: UIGestureRecognizer.State, primary: Bool, secondary: Bool, middle: Bool) {
        // Implement cursor drag logic here
    }

    func pencilRightClickForTouch(_ touch: UITouch) -> Bool {
        // Implement logic for checking Pencil right-click behavior
        return false
    }
}

