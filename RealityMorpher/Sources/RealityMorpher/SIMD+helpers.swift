//
//  SIMD+helpers.swift
//  
//
//  Created by Oliver Dew on 11/08/2023.
//

import simd
import SwiftUI

extension SIMD4 {
	var xyz: SIMD3<Scalar> {
		get {
			SIMD3(x: x, y: y, z: z)
		}
		set {
			self = SIMD4(newValue, w)
		}
	}
}

extension SIMD3: VectorArithmetic & AdditiveArithmetic where Scalar == Float {
	public mutating func scale(by rhs: Double) {
		self *= Float(rhs)
	}
	
	public var magnitudeSquared: Double {
		length_squared(SIMD3<Double>(self))
	}
}
