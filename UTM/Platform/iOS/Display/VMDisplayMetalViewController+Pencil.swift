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

@available(iOS 12.1, *)
extension VMDisplayMetalViewController {

    // MARK: - Pencil Interaction Initialization

    func initPencilInteraction() {
        tapPencil = UITapGestureRecognizer(target: self, action: #selector(pencilGestureTap(_:)))
        tapPencil.delegate = self
        tapPencil.allowedTouchTypes = [.pencil]
        tapPencil.cancelsTouchesInView = false
        mtkView.addGestureRecognizer(tapPencil)

        let interaction = UIPencilInteraction()
        interaction.delegate = self
        mtkView.addInteraction(interaction)
    }

    // MARK: - UIPencilInteractionDelegate Implementation

    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        // Only support one action: switching to right click for the next click
        pencilForceRightClickOnce = true
    }

    // MARK: - UITapGestureRecognizer

    @IBAction func pencilGestureTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended, serverModeCursor {
            var button: CSInputButton = .left

            if #available(iOS 12.1, *) {
                if pencilForceRightClickOnce {
                    button = .right
                    pencilForceRightClickOnce = false
                }
            }

            mouseClick(button: button, location: sender.location(in: sender.view))
        }
    }

    // MARK: - Gesture Handling

    func pencilGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOfGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == tapPencil && otherGestureRecognizer == twoTap {
            return true
        }
        if gestureRecognizer == longPress && otherGestureRecognizer == tapPencil {
            return true
        }
        return false
    }

    func pencilRightClick(for touch: UITouch) -> Bool {
        if touch.type == .pencil {
            let hasRightClick = pencilForceRightClickOnce
            pencilForceRightClickOnce = false
            return hasRightClick
        } else {
            return false
        }
    }
}

