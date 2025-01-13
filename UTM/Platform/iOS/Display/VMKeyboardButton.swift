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

@IBDesignable
final class VMKeyboardButton: UIButton {
    @IBInspectable var keyAppearance: UIKeyboardAppearance
    @IBInspectable var secondary: Bool
    @IBInspectable var toggleable: Bool
    @IBInspectable var scanCode: Int
    @IBInspectable var toggled: Bool

    private func setup() {
        layer.cornerRadius = 5
        layer.shadowOffset = CGSize(0, 1)
        layer.shadowOpacity = 0.4
        layer.shadowRadius = 0
        backgroundColor = defaultColor
        keyAppearance = traitCollection.userInterfaceStyle == .dark ? .dark : .light

        accessibilityTraits |= .keyboardKey
        if (toggleable) {
            accessibilityTraits |= .toggleButton;
        }
    }

    override class func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        keyAppearance = traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }

    private var primaryColor: UIColor {
        keyAppearance == .light ? .white : UIColor(red: 1, green: 1, blue: 1, alpha: 77/255.0)
    }

    private var secondaryColor: UIColor {
        keyAppearance == .light ? UIColor(red: 172/255.0, green: 180/255.0, blue: 190/255.0, alpha: 1) : UIColor(red: 147/255.0, green: 147/255.0, blue: 147/255.0, alpha: 66/255.0)
    }

    private var defaultColor: UIColor {
        secondary ? secondaryColor : primaryColor
    }

    private var highlightColor: UIColor {
        !secondary ? secondaryColor : primaryColor
    }

    private func chooseBackground() {
        if selected || highlighted || (toggleable && toggled) {
            backgroundColor = highlightedColor
        } else {
            UIView.animate(withDuration: 0, delay: 0.1, options: .allowUserInteraction) {
                backgroundColor = defaultColor
            }
        }

        tintColor = keyAppearance == .light ? .black : .white
        setTitleColor(tintColor, for: .normal)
    }

    override var isHighlighted: Bool {
        get { super.isHighlighted }
        set {
            super.isHighlighted = newValue
            chooseBackground()
        }
    }

    func setToggled(_ newValue: Bool) {
        toggled = newValue
        chooseBackground()
    }

    func setKeyAppearance(_ newValue: UIKeyboardAppearance) {
        keyAppearance = newValue
        chooseBackground()
    }

    override var accessibilityValue: String? {
        toggleable ? (isSelected ? "1" : "0") : nil
    }

    override class func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        setup()
    }

}
