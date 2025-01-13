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

let kLargeAccessoryViewHeight: Int = 100
let kSmallAccessoryViewHeight: Int = 50
let kSafeAreaHeight: Int = 20

final class VMKeyboardView: UIView, UITextInputTraits, UIKeyInput {

    @IBOutlet weak var delegate: (any VMKeyboardViewDelegate)?
    @IBOutlet var inputAccessoryView: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureTables()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureTables()
    }

    // MARK: - UITextInputTraits Implementation

    override var keyboardType: UIKeyboardType { .asciiCapable }
    override var autocapitalizationType: UITextAutocapitalizationType { .none }
    override var autocorrectionType: UITextAutocorrectionType { .no }
    override var spellCheckingType: UITextSpellCheckingType { .no }
    override var smartQuotesType: UITextSmartQuotesType { .no }
    override var smartDashesType: UITextSmartDashesType { .no }
    override var smartInsertDeleteType: UITextSmartInsertDeleteType { .no }

    // MARK: - Key Input

    override var hasText: Bool { true }
    override var canBecomeFirstResponder: Bool { true }

    func insertText(_ text: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            for character in text {
                insertTextCharacter(character)
            }
        }
    }

    func deleteBackward() {
        delegate?.keyboardView(self, didPressKeyDown: 0x0E)
        Thread.sleep(forTimeInterval: 0.05)
        delegate?.keyboardView(self, didPressKeyUp: 0x0E)
    }

    private func insertText(_ text: String) {
        text.withUTF8(insertUTF8)
        // we need to pause a bit or the keypress will be too fast!
        Thread.sleep(forTimeInterval: 0.001)
    }

    private func insertUTF8(_ buffer: UnsafeBufferPointer<UInt8>) {
        guard var tc = buffer.first else { return }
        var keycode = 0
        var special = 0
        var prekey = 0
        var prekey_special = 0
        var is_upper = false

        if isalpha(tc) && isupper(tc) {
            tc = tolower(tc);
            is_upper = true;
        }

        switch (buffer.count) {
        case 1:
            let i = keymap_index_of(&map, map.count, tc)
            if i != -1 {
                keycode = map[i].key
                special = map[i].special_key
            }
        case 2:
            let i = keymap_index_of_ext(&extMap, extMap.count, tc, buffer[1], 0)
            if i != -1 {
                keycode = extMap[i].key
                special = extMap[i].special_key
                prekey = extMap[i].prekey
                prekey_special = extMap[i].special_prekey
            }
        case 3:
            let i = keymap_index_of_ext(&extMap, extMap.count, tc, buffer[1], buffer[2])
            if i != -1 {
                keycode = extMap[i].key
                special = extMap[i].special_key
                prekey = extMap[i].prekey
                prekey_special = extMap[i].special_prekey
            }
        }

        if keycode != 0 {
            if is_upper {
                special = 0x2A
            }

            if prekey != 0 {
                if prekey_special != 0 {
                    delegate?.keyboardView(self, didPressKeyDown: prekey_special)
                }
                delegate?.keyboardView(self, didPressKeyDown: prekey)
                Thread.sleep(forTimeInterval: 0.05)
                delegate?.keyboardView(self, didPressKeyUp: prekey)
                if prekey_special {
                    delegate?.keyboardView(self, didPressKeyUp: prekey_special)
                }
            }

            if special != 0 {
                delegate?.keyboardView(self, didPressKeyDown: special)
            }
            delegate?.keyboardView(self, didPressKeyDown: keycode)
            Thread.sleep(forTimeInterval: 0.05)
            delegate?.keyboardView(self, didPressKeyUp: keycode)
            if special {
                delegate?.keyboardView(self, didPressKeyUp: special)
            }
        }
    }

    // MARK: - Key Mapping Configuration

    private var map: [key_map_t] = []
    private var extMap: [ext_key_map_t] = []

    private func configureTables() {
        switch Locale.preferredLanguages.first {
        case "es-ES":
            map = pc104_es
            extMap = pc104_es_ext
        default:
            map = pc104_us
            extMap = pc104_us_ext
        }
    }
}
