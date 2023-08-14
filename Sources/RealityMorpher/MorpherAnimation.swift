//
//  MorpherAnimation.swift
//
//
//  Created by Oliver Dew on 11/08/2023.
//

import Foundation

/// Describes how a change in morph target weighting should be animated
@available(iOS 17.0, macOS 14.0, *)
public enum MorpherAnimation {
	case linear(duration: TimeInterval)
	case cubic(duration: TimeInterval)
	
	/// - Parameters:
	///   - duration: duration of animation in seconds
	///   - bounce: The bounciness of the spring. 0 is fully damped, 1 is not damped at all. High bounciness will increase the duration of the transition
	case spring(duration: TimeInterval, bounce: Double = 0.2)
	
	/// Change in weights is applied immediately with no animation
	public static var noAnimation: MorpherAnimation { .linear(duration: 0) }
}
