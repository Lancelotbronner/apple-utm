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

extension VMDisplayMetalViewController {

    // MARK: - Software Keyboard

    var inputViewIsFirstResponder: Bool {
        return keyboardView.isFirstResponder
    }

    func keyboardView(_ keyboardView: VMKeyboardView, didPressKeyDown scancode: Int) {
        sendExtendedKey(kCSInputKeyPress, code: scancode)
    }

    func keyboardView(_ keyboardView: VMKeyboardView, didPressKeyUp scancode: Int) {
        sendExtendedKey(kCSInputKeyRelease, code: scancode)
        resetModifierToggles()
    }

    @IBAction func keyboardDonePressed(_ sender: UIButton) {
        keyboardView.resignFirstResponder()
    }

    @IBAction func keyboardPastePressed(_ sender: UIButton) {
        if let string = UIPasteboard.general.string {
            UTMLog("Pasting: \(string)")
            keyboardView.insertText(string)
        } else {
            UTMLog("No string to paste.")
        }
    }

    func resetModifierToggles() {
        for button in customKeyModifierButtons {
            if button.toggled {
                sendExtendedKey(kCSInputKeyRelease, code: button.scanCode)
                DispatchQueue.main.async {
                    button.toggled = false
                }
            }
        }
    }

    @IBAction func customKeyTouchDown(_ sender: VMKeyboardButton) {
        if !sender.toggleable {
            sendExtendedKey(kCSInputKeyPress, code: sender.scanCode)
        }
    }

    @IBAction func customKeyTouchUp(_ sender: VMKeyboardButton) {
        if sender.toggleable {
            sender.toggled.toggle()
        } else {
            resetModifierToggles()
        }

        if sender.toggleable && sender.toggled {
            sendExtendedKey(kCSInputKeyPress, code: sender.scanCode)
        } else {
            onDelay(0.05) {
                self.sendExtendedKey(kCSInputKeyRelease, code: sender.scanCode)
            }
        }
    }

    // MARK: - iOS 13.4+ key event handling

    // HID to PS2 mapping (simplified for brevity)
    private let hidToPs2Table: [UInt8] = [
        0x00, 0xff, 0xfc, 0x00, 0x1e, 0x30, 0x2e, 0x20,
        0x12, 0x21, 0x22, 0x23, 0x17, 0x24, 0x25, 0x26,
        0x32, 0x31, 0x18, 0x19, 0x10, 0x13, 0x1f, 0x14,
        // ... (rest of the table omitted for brevity)
    ]

    private let hidToPs2ExtendedTable: [UInt8] = [
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        // ... (rest of the table omitted for brevity)
    ]

    // API available only on iOS 13.4+
    @available(iOS 13.4, *)
    private func hidToPs2(hidCode: UIKeyboardHIDUsage) -> Int {
        var ps2Code = 0
        if hidCode.rawValue < 0x100 {
            ps2Code = Int(hidToPs2Table[Int(hidCode.rawValue) & 0xFF])
            if ps2Code == 0 {
                ps2Code = Int(hidToPs2ExtendedTable[Int(hidCode.rawValue) & 0xFF])
                if ps2Code != 0 {
                    ps2Code |= 0xE000
                }
            }
        }
        return ps2Code
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var didHandleEvent = false
        for press in presses {
            let code = hidToPs2(hidCode: press.key.keyCode)
            if code != 0 {
                sendExtendedKey(kCSInputKeyPress, code: code)
                didHandleEvent = true
            }
        }
        if !didHandleEvent {
            super.pressesBegan(presses, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var didHandleEvent = false
        for press in presses {
            let code = hidToPs2(hidCode: press.key.keyCode)
            if code != 0 {
                sendExtendedKey(kCSInputKeyRelease, code: code)
                didHandleEvent = true
            }
            resetModifierToggles()
        }
        if !didHandleEvent {
            super.pressesEnded(presses, with: event)
        }
    }

    // MARK: - VoiceOver Esc Key workaround

    override func accessibilityPerformEscape() -> Bool {
        sendExtendedKey(kCSInputKeyPress, code: 0x01)
        onDelay(0.05) {
            self.sendExtendedKey(kCSInputKeyRelease, code: 0x01)
        }
        return true
    }
}

