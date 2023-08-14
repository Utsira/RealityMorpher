import XCTest
import Metal
import Accelerate
import RealityKit
@testable import RealityMorpher

final class MorphComponentTests: XCTestCase {
	override class func setUp() {
		MorphComponent.registerComponent()
	}
	
	func testGeneratedPositionsNormalsTexture() throws {
		let material = SimpleMaterial()
		// base is XZ unit plane
		let base = ModelEntity(mesh: .generatePlane(width: 1, depth: 1),materials: [material])
		
		// target0 still XZ, but wider in X axis
		let target = ModelComponent(mesh: .generatePlane(width: 3, depth: 1), materials: [material])
		
		// target1 is a unit plane, but on XY
		let target1 = ModelComponent(mesh: .generatePlane(width: 1, height: 1), materials: [material])
		
		let sut = try MorphComponent(entity: base, targets: [target, target1])
		let texture = try XCTUnwrap(sut.textureResources.first)
		XCTAssertEqual(texture.width, 4)
		XCTAssertEqual(texture.height, 4) // positions & normals for 2 targets
		
		// target 0
		let (positions0, normals0) = try texture.getPositionsAndNormals(targetIndex: 0, targetCount: 2, vertCount: 4)
		// expect the geometry to expand by 1 unit in each direction on the x-axis
		XCTAssertEqual(positions0, [
			[-1, 0, 0],
			[1, 0, 0],
			[-1, 0, 0],
			[1, 0, 0]
		])
		// normals all point up still
		XCTAssertEqual(normals0, Array(repeating: [0, 1, 0], count: 4))
		
		// target 1
		let (positions1, normals1) = try texture.getPositionsAndNormals(targetIndex: 1, targetCount: 2, vertCount: 4)
		// expect geometry to rotate around x-axis
		XCTAssertEqual(positions1, [
			[0.0, -0.5, -0.5],
			[0.0, -0.5, -0.5],
			[0.0, 0.5, 0.5],
			[0.0, 0.5, 0.5]
		])
		// normals now point forwards
		XCTAssertEqual(normals1, Array(repeating: [0, 0, 1], count: 4))
	}
	
	func testGeometryWithMoreVerticesThanMaxTextureWidth() throws {
		let maxWidth = 8192
		let material = SimpleMaterial()
		let base = ModelEntity(mesh: try largeMesh(vertCount: maxWidth + 1, ramp: 0...100), materials: [material])
		// all positions in target are offset by [1, 1, 1]
		let target = ModelComponent(mesh: try largeMesh(vertCount: maxWidth + 1, ramp: 1...101), materials: [material])
		let sut = try MorphComponent(entity: base, targets: [target])
		
		let texture = try XCTUnwrap(sut.textureResources.first)
		XCTAssertEqual(texture.width, maxWidth)
		XCTAssertEqual(texture.height, 3) // positions & normals overspilling onto a third row by 2 pixels
		
		let (positions0, _) = try texture.getPositionsAndNormals(targetIndex: 0, targetCount: 1, vertCount: maxWidth + 1)
		XCTAssertEqual(positions0, Array(repeating: .one, count: maxWidth + 1))
	}
	
	func testAnimation() throws {
		let material = SimpleMaterial()
		let base = ModelEntity(mesh: .generatePlane(width: 1, depth: 1),materials: [material])
		let target = ModelComponent(mesh: .generatePlane(width: 3, depth: 1), materials: [material])
		var sut = try MorphComponent(entity: base, targets: [target])
		if #available(iOS 17.0, macOS 14.0, *) {
			sut.setTargetWeights([1], animation: .cubic(duration: 2))
		} else {
			sut.setTargetWeights([1], duration: 2)
		}
		XCTAssertEqual(sut.weights.values, [1, 0, 0, 0]) // immediately reports target weight
		sut = try XCTUnwrap(sut.updated(deltaTime: 1))
		XCTAssertEqual(sut.currentWeights, [0.5, 0, 0, 0]) // midpoint of the animation
		sut = try XCTUnwrap(sut.updated(deltaTime: 1))
		XCTAssertEqual(sut.currentWeights, [1, 0, 0, 0]) // end of the animation
		XCTAssertNil(sut.updated(deltaTime: 1)) // no update past the end of the animation
	}
	
	// MARK: - MorphComponent.Error
	
	func testTargetNotTopologicallyIdentical() throws {
		let material = SimpleMaterial()
		let base = ModelEntity(mesh: .generatePlane(width: 1, depth: 1),materials: [material])
		let target = ModelComponent(mesh: .generatePlane(width: 1, depth: 1, cornerRadius: 0.1), materials: [material])
		do {
			let _ = try MorphComponent(entity: base, targets: [target])
			XCTFail()
		} catch let error as MorphComponent.Error {
			XCTAssertEqual(error, .targetsNotTopologicallyIdentical)
		}
	}
	
	func testMissingNormals() throws {
		let material = SimpleMaterial()
		let base = ModelEntity(mesh: .generatePlane(width: 1, depth: 1),materials: [material])
		let target = ModelComponent(mesh: .generatePlane(width: 3, depth: 1), materials: [material])
		
		var updatedContents = MeshResource.Contents()
		updatedContents.instances = target.mesh.contents.instances
		
		updatedContents.models = MeshModelCollection(target.mesh.contents.models.map { submodel in
			MeshResource.Model(id: submodel.id, parts: submodel.parts.map { part in
				var newPart = part
				newPart.normals = nil
				return newPart
			})
		})
		let targetNoNormals = ModelComponent(mesh: try MeshResource.generate(from: updatedContents), materials: target.materials)
		do {
			let _ = try MorphComponent(entity: base, targets: [targetNoNormals])
			XCTFail()
		} catch let error as MorphComponent.Error {
			XCTAssertEqual(error, .positionsCountNotEqualToNormalsCount)
		}
	}
	
	func testBaseMeshMissing() throws {
		let base = ModelEntity()
		let material = SimpleMaterial()
		let target = ModelComponent(mesh: .generatePlane(width: 1, depth: 1, cornerRadius: 0.1), materials: [material])
		do {
			let _ = try MorphComponent(entity: base, targets: [target])
			XCTFail()
		} catch let error as MorphComponent.Error {
			XCTAssertEqual(error, .missingBaseMesh)
		}
	}
	
	func testTargetMissing() throws {
		let material = SimpleMaterial()
		let base = ModelEntity(mesh: .generatePlane(width: 1, depth: 1),materials: [material])
		do {
			let _ = try MorphComponent(entity: base, targets: [])
			XCTFail()
		} catch let error as MorphComponent.Error {
			XCTAssertEqual(error, .invalidNumberOfTargets)
		}
	}
	
	func testTooManyTargets() throws {
		let material = SimpleMaterial()
		let base = ModelEntity(mesh: .generatePlane(width: 1, depth: 1),materials: [material])
		let target = ModelComponent(mesh: .generatePlane(width: 1, depth: 1), materials: [material])
		do {
			let _ = try MorphComponent(entity: base, targets: [target, target, target, target, target])
			XCTFail()
		} catch let error as MorphComponent.Error {
			XCTAssertEqual(error, .invalidNumberOfTargets)
		}
	}
	
	// MARK: Helpers
	/// Use Accelerate to quickly generate a large mesh
	private func largeMesh(vertCount: Int, ramp: ClosedRange<Float>) throws -> MeshResource {
		var descriptor = MeshDescriptor()
		let elements: [Float] = vDSP.ramp(in: ramp, count: vertCount * 4) // multiuply by 4 because SIMD3 isn't packed, it has a memory layout of 16 bytes. Every 4th element (the .w component) will be ignored when we bind
		let positions = Array(elements.withUnsafeBytes {
			$0.bindMemory(to: SIMD3<Float>.self)
		})
		descriptor.positions = MeshBuffers.Positions(positions)
		descriptor.normals = MeshBuffers.Normals(Array(repeating: [1, 0, 0], count: vertCount))
		descriptor.primitives = .triangles(Array(0..<UInt32(vertCount)))
		descriptor.materials = .allFaces(0)
		return try MeshResource.generate(from: [descriptor])
	}
}

extension TextureResource {
	struct ParseDataError: Error {}
	func getPositionsAndNormals(targetIndex: Int, targetCount: Int, vertCount: Int) throws -> (positions: [SIMD3<Float>], normals: [SIMD3<Float>]) {
		guard let device = MTLCreateSystemDefaultDevice() else { throw ParseDataError() }
		let descriptor = MTLTextureDescriptor.texture2DDescriptor(
			pixelFormat: .rgba16Float,
			width: width,
			height: height,
			mipmapped: false)
		descriptor.usage = .shaderWrite // Required for copy

		guard let texture = device.makeTexture(descriptor: descriptor) else { throw ParseDataError() }
		try copy(to: texture)

		#if os(OSX) // Managed mode exists only in OSX
		if texture.storageMode == .managed {
			// Managed textures need to be synchronized before accessing their data
			guard let commandBuffer = device.makeCommandQueue()?.makeCommandBuffer(),
				  let blitEncoder = commandBuffer.makeBlitCommandEncoder()
			else { throw ParseDataError() }

			blitEncoder.synchronize(resource: texture)
			blitEncoder.endEncoding()
			commandBuffer.commit()
			commandBuffer.waitUntilCompleted()
		}
		#endif

		// Getting raw pixel bytes
		let bytesPerRow = MemoryLayout<SIMD4<Float16>>.stride * texture.width
		var elements = [SIMD4<Float16>](repeating: .zero, count: texture.width * texture.height)
		elements.withUnsafeMutableBytes { bytesPtr in
			texture.getBytes(
				bytesPtr.baseAddress!,
				bytesPerRow: bytesPerRow,
				from: .init(origin: .init(), size: .init(width: texture.width, height: texture.height, depth: 1)),
				mipmapLevel: 0
			)
		}
		var positions: [SIMD3<Float>] = []
		var normals: [SIMD3<Float>] = []
		for index in 0..<vertCount {
			let elementId = ((index * targetCount) + targetIndex) * 2
			positions.append(SIMD3<Float>(elements[elementId].xyz))
			normals.append(SIMD3<Float>(elements[elementId + 1].xyz))
		}
		return (positions: positions, normals: normals)
	}
}
