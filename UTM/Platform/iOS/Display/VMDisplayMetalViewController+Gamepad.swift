// VMDisplayMetalViewController+Gamepad.swift
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

import Foundation
import GameController

let kThumbstickSpeedMultiplier: CGFloat = 1000 // in points per second

extension VMDisplayMetalViewController {

    func initGamepad() {
        // notifications for controller (dis)connect
        NotificationCenter.default.addObserver(self, selector: #selector(controllerWasConnected(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(controllerWasDisconnected(_:)), name: .GCControllerDidDisconnect, object: nil)

        // Setup all connected controllers
        for controller in GCController.controllers() {
            setupController(controller)
        }
    }

    // MARK: - Gamepad connection

    @objc func controllerWasConnected(_ notification: Notification) {
        // a controller was connected
        guard let controller = notification.object as? GCController else { return }
        UTMLog("Controller connected: \(controller.vendorName ?? "Unknown")")
        setupController(controller)
    }

    @objc func controllerWasDisconnected(_ notification: Notification) {
        // a controller was disconnected
        guard let controller = notification.object as? GCController else { return }
        UTMLog("Controller disconnected: \(controller.vendorName ?? "Unknown")")
    }

    func setupController(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }
        self.controller = controller
        UTMLog("Active controller switched to: \(controller.vendorName ?? "Unknown")")

        gamepad.leftTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.gamepadButton(identifier: "GCButtonTriggerLeft", pressed: pressed)
        }

        gamepad.rightTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.gamepadButton(identifier: "GCButtonTriggerRight", pressed: pressed)
        }

        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.gamepadButton(identifier: "GCButtonShoulderLeft", pressed: pressed)
        }

        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.gamepadButton(identifier: "GCButtonShoulderRight", pressed: pressed)
        }

        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.gamepadButton(identifier: "GCButtonA", pressed: pressed)
        }

        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.gamepadButton(identifier: "GCButtonB", pressed: pressed)
        }

        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.gamepadButton(identifier: "GCButtonX", pressed: pressed)
        }

        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.gamepadButton(identifier: "GCButtonY", pressed: pressed)
        }

        gamepad.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.gamepadButton(identifier: "GCButtonDpadUp", pressed: pressed)
        }

        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.gamepadButton(identifier: "GCButtonDpadLeft", pressed: pressed)
        }

        gamepad.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.gamepadButton(identifier: "GCButtonDpadDown", pressed: pressed)
        }

        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.gamepadButton(identifier: "GCButtonDpadRight", pressed: pressed)
        }

        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            guard let self = self else { return }
            let velocity = CGPoint(x: xValue * kThumbstickSpeedMultiplier, y: -yValue * kThumbstickSpeedMultiplier)
            self.scroll.startMovement(.zero)
            self.scroll.updateMovement(CGPoint(x: xValue, y: yValue))
            self.scroll.endMovement(withVelocity: velocity, resistance: 0)
        }

        gamepad.rightThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            guard let self = self else { return }
            let speed = self.integerForSetting("GCThumbstickRightSpeed")
            let center = self.cursor.center
            let start = CGPoint(x: xValue * CGFloat(speed), y: -yValue * CGFloat(speed))
            let velocity = CGPoint(x: xValue * kThumbstickSpeedMultiplier, y: -yValue * kThumbstickSpeedMultiplier)
            self.cursor.startMovement(center)
            self.cursor.updateMovement(CGPoint(x: center.x + start.x, y: center.y + start.y))
            self.cursor.endMovement(withVelocity: velocity, resistance: 0)
        }

        if #available(iOS 13.0, *) {
            gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
                self?.gamepadButton(identifier: "GCButtonMenu", pressed: pressed)
            }
        }
    }

    func gamepadButton(identifier: String, pressed: Bool) {
        let value = integerForSetting(identifier)
        UTMLog("GC button \(identifier) (\(value)) pressed: \(pressed)")

        switch value {
        case 0:
            break
        case -1:
            vmInput.sendMouseButton(.left, pressed: pressed)
            mouseLeftDown = pressed
        case -3:
            vmInput.sendMouseButton(.right, pressed: pressed)
            mouseRightDown = pressed
        case -2:
            vmInput.sendMouseButton(.middle, pressed: pressed)
            mouseMiddleDown = pressed
        default:
            sendExtendedKey(pressed ? .keyPress : .keyRelease, code: Int32(value))
        }
    }
}

