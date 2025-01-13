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

final class VMCursor: NSObject, UIDynamicItem {

    var _bounds: CGRect
    var transform: CGAffineTransform = .identity

    private var _start: CGPoint = .zero
    private var _lastCenter: CGPoint = .zero
    private weak var _controller: VMDisplayMetalViewController?
    private var _animator: UIDynamicAnimator

    private var cursorSpeedMultiplier: CGFloat {
        let multiplier = UserDefaults.standard.integer(forKey: "DragCursorSpeed")
        let fraction = CGFloat(multiplier) / 100.0
        return fraction > 0 ? fraction : 1.0
    }

    override init() {
        _bounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        _animator = UIDynamicAnimator()
        super.init()
    }

    init(controller: VMDisplayMetalViewController) {
        _bounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        _animator = UIDynamicAnimator()
        _controller = controller
        super.init()
    }

    var bounds: CGRect {
        let width = max(1, _controller?.vmDisplay.cursor?.cursorSize.width ?? 1)
        let height = max(1, _controller?.vmDisplay.cursor?.cursorSize.height ?? 1)
        return CGRect(x: 0, y: 0, width: width, height: height)
    }

    public var center: CGPoint {
        willSet {
//            _controller?.moveMouse(to: newValue, from: _lastCenter, by: cursorSpeedMultiplier)
            if _controller?.serverModeCursor == true {
                let diff = CGPoint(
                    x: (newValue.x - _lastCenter.x) * cursorSpeedMultiplier,
                    y: (newValue.y - _lastCenter.y) * cursorSpeedMultiplier)
                _controller?.moveMouseRelative(diff)
            } else {
                _controller?.moveMouseAbsolute(newValue)
            }
            _lastCenter = center
        }
    }

    func startMovement(startPoint: CGPoint) {
        _start = startPoint
        if _controller?.serverModeCursor == false {
            _lastCenter = startPoint
            _center = startPoint
        }
        _animator.removeAllBehaviors()
    }

    func updateMovement(point: CGPoint) {
        var newPoint = point
        if _controller?.serverModeCursor == true {
            // translate point to relative to last center
            let adj = CGPoint(x: point.x - _start.x, y: point.y - _start.y)
            _start = point
            newPoint = CGPoint(x: center.x + adj.x, y: center.y + adj.y)
        }
        center = newPoint
    }

    func endMovementWithVelocity(velocity: CGPoint, resistance: CGFloat) {
        let behavior = UIDynamicItemBehavior(items: [self])
        behavior.addLinearVelocity(velocity, for: self)
        behavior.resistance = resistance
        _animator.addBehavior(behavior)
    }
}
