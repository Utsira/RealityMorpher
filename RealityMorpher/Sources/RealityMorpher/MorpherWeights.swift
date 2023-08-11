//
//  MorpherWeights.swift
//  
//
//  Created by Oliver Dew on 11/08/2023.
//

import simd
import SwiftUI

@dynamicMemberLookup
public struct MorpherWeights: Animatable, ExpressibleByArrayLiteral {
	public private(set) var values: SIMD3<Float>
	
	public var animatableData: SIMD3<Float> {
		get { values }
		set { values = newValue }
	}
	
	public init(_ targets: SIMD3<Float>) {
		self.values = targets
	}
	
	public init(arrayLiteral elements: Float...) {
		values = SIMD3(elements)
	}
	
	public subscript(dynamicMember keyPath: KeyPath<SIMD3<Float>, Float>) -> Float {
		values[keyPath: keyPath]
	}
	
	public static var zero: MorpherWeights {
		MorpherWeights(.zero)
	}
}
