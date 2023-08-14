//
//  MorpherAnimating.swift
//  
//
//  Created by Oliver Dew on 11/08/2023.
//

import simd
import SwiftUI

protocol MorpherAnimating {
	mutating func update(with deltaTime: TimeInterval) -> MorpherEvent
}

struct MorpherEvent {
	enum Status {
		case running, completed
	}
	let status: Status
	let weights: MorpherWeights
}

@available(iOS 17.0, macOS 14.0, *)
struct TimelineAnimator: MorpherAnimating {
	let timeline: KeyframeTimeline<MorpherWeights>
	private var timeElapsed: TimeInterval = .zero
	
	init(origin: MorpherWeights, target: MorpherWeights, animation: MorpherAnimation) {
		timeline = KeyframeTimeline(initialValue: origin) {
			switch animation.mode {
			case .linear:
				LinearKeyframe(target, duration: animation.duration)
			case .cubic:
				CubicKeyframe(target, duration: animation.duration)
			case .spring(let bounce):
				SpringKeyframe(target, spring: Spring(duration: animation.duration, bounce: bounce))
			}
		}
	}
	
	init(origin: MorpherWeights, @KeyframesBuilder<MorpherWeights> animations: () -> some Keyframes<MorpherWeights>) {
		timeline = KeyframeTimeline(initialValue: origin, content: animations)
	}
	
	mutating func update(with deltaTime: TimeInterval) -> MorpherEvent {
		if timeElapsed >= timeline.duration {
			return MorpherEvent(status: .completed, weights: timeline.value(progress: 1))
		}
		timeElapsed += deltaTime
		let value = timeline.value(time: timeElapsed)
		return MorpherEvent(status: .running, weights: value)
	}
}

struct LinearAnimator: MorpherAnimating {
	private var timeElapsed: TimeInterval = .zero
	private let origin: MorpherWeights
	private let target: MorpherWeights
	private let animation: MorpherAnimation
	
	init(origin: MorpherWeights, target: MorpherWeights, animation: MorpherAnimation) {
		self.origin = origin
		self.target = target
		self.animation = animation
	}
	
	mutating func update(with deltaTime: TimeInterval) -> MorpherEvent {
		if timeElapsed >= animation.duration {
			return MorpherEvent(status: .completed, weights: target)
		}
		timeElapsed += deltaTime
		let value = mix(origin.values, target.values, t: Float(timeElapsed / animation.duration))
		return MorpherEvent(status: .running, weights: MorpherWeights(values: value))
	}
}
