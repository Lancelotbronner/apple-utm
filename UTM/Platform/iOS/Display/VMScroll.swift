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

final class VMScroll: NSObject, UIDynamicItem {

    var bounds: CGRect
    var transform: CGAffineTransform = .identity

    private var _start: CGPoint = .zero
    private var _lastCenter: CGPoint = .zero
    private weak var _controller: VMDisplayMetalViewController?
    private var _animator: UIDynamicAnimator

    override init() {
        bounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        _animator = UIDynamicAnimator()
        super.init()
    }

    init(controller: VMDisplayMetalViewController) {
        bounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        _animator = UIDynamicAnimator()
        _controller = controller
        super.init()
    }

    public private(set) var center: CGPoint {
        willSet {
            let diff = CGPoint(x: newValue.x - _lastCenter.x, y: newValue.y - _lastCenter.y)
            _controller?.moveMouseScroll(diff)
            _lastCenter = _center
        }
    }

    func startMovement(startPoint: CGPoint) {
        _start = startPoint
        _animator.removeAllBehaviors()
    }

    func updateMovement(point: CGPoint) {
        // translate point to relative to last center
        let adj = CGPoint(x: point.x - _start.x, y: point.y - _start.y)
        _start = point
        center = CGPoint(x: center.x + adj.x, y: center.y + adj.y)
    }

    func endMovement(withVelocity velocity: CGPoint, resistance: CGFloat) {
        let behavior = UIDynamicItemBehavior(items: [self])
        behavior.addLinearVelocity(velocity, for: self)
        behavior.resistance = resistance
        _animator.addBehavior(behavior)
    }
    
}
