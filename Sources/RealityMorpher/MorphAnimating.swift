//
//  MorphAnimating.swift
//  
//
//  Created by Oliver Dew on 11/08/2023.
//

import simd
import SwiftUI

protocol MorphAnimating {
	mutating func update(with deltaTime: TimeInterval) -> MorphEvent
}

struct MorphEvent {
	enum Status {
		case running, completed
	}
	let status: Status
	let weights: MorphWeights
}

@available(iOS 17.0, macOS 14.0, *)
struct TimelineAnimator: MorphAnimating {
	let timeline: KeyframeTimeline<MorphWeights>
	private var timeElapsed: TimeInterval = .zero
	
	init(origin: MorphWeights, target: MorphWeights, animation: MorphAnimation) {
		timeline = KeyframeTimeline(initialValue: origin) {
			switch animation {
			case .linear(let duration):
				LinearKeyframe(target, duration: duration)
			case .cubic(let duration):
				CubicKeyframe(target, duration: duration)
			case let .spring(duration, bounce):
				SpringKeyframe(target, spring: Spring(duration: duration, bounce: bounce))
			}
		}
	}
	
	init(origin: MorphWeights, @KeyframesBuilder<MorphWeights> animations: () -> some Keyframes<MorphWeights>) {
		timeline = KeyframeTimeline(initialValue: origin, content: animations)
	}
	
	mutating func update(with deltaTime: TimeInterval) -> MorphEvent {
		if timeElapsed >= timeline.duration {
			return MorphEvent(status: .completed, weights: timeline.value(progress: 1))
		}
		timeElapsed += deltaTime
		let value = timeline.value(time: timeElapsed)
		return MorphEvent(status: .running, weights: value)
	}
}

struct LinearAnimator: MorphAnimating {
	private var timeElapsed: TimeInterval = .zero
	private let origin: MorphWeights
	private let target: MorphWeights
	private let duration: TimeInterval
	
	init(origin: MorphWeights, target: MorphWeights, duration: TimeInterval) {
		self.origin = origin
		self.target = target
		self.duration = duration
	}
	
	mutating func update(with deltaTime: TimeInterval) -> MorphEvent {
		if timeElapsed >= duration {
			return MorphEvent(status: .completed, weights: target)
		}
		timeElapsed += deltaTime
		let value = mix(origin.values, target.values, t: Float(timeElapsed / duration))
		return MorphEvent(status: .running, weights: MorphWeights(values: value))
	}
}
