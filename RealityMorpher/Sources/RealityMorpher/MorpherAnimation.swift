//
//  MorpherAnimation.swift
//
//
//  Created by Oliver Dew on 11/08/2023.
//

import Foundation

public struct MorpherAnimation {
	public enum InterpolationMode {
		case linear, cubic, spring(bounce: Double)
		
		public static var spring: InterpolationMode { .spring(bounce: 0.2) }
	}
	
	public let duration: TimeInterval
	public let mode: InterpolationMode
	
	public init(duration: TimeInterval, mode: InterpolationMode) {
		self.duration = duration
		self.mode = mode
	}
	
	public static var immediate: MorpherAnimation {
		MorpherAnimation(duration: 0, mode: .linear)
	}
}

