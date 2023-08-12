//
//  MorpherAnimation.swift
//
//
//  Created by Oliver Dew on 11/08/2023.
//

import Foundation
import SwiftUI
/// Describes how a change in morph target weighting should be animated
public struct MorpherAnimation {
	/// How the animation is tweened.
	public enum InterpolationMode {
		case linear
		/// Cubic animation. Requires iOS 17/ macOS 14
		case cubic
		/// Spring animation. Requires iOS 17/ macOS 14
		/// - Parameters:
		///   - bounce: The bounciness of the spring. 0 is fully damped, 1 is not damped at all. High bounciness will increase the duration of the transition
		case spring(bounce: Double)

		/// A default spring with a bounciness of 0.2 (highly damped).
		public static var spring: InterpolationMode { .spring(bounce: 0.2) }
	}
	
	public let duration: TimeInterval
	public let mode: InterpolationMode
	
	/// Describes how a change in morph target weighting should be animated
	/// - Parameters:
	///   - duration: length of the animation in seconds
	///   - mode: the animation's ``InterpolationMode``
	public init(duration: TimeInterval, mode: InterpolationMode) {
		self.duration = duration
		self.mode = mode
	}
	
	/// An animation with a duration of zero
	public static var immediate: MorpherAnimation {
		MorpherAnimation(duration: 0, mode: .linear)
	}
}

