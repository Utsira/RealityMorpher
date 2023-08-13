import XCTest
import Metal
import RealityKit
@testable import RealityMorpher
import RealityMorpherKernels

final class MorpherComponentTests: XCTestCase {
	override class func setUp() {
		MorpherComponent.registerComponent()
	}
	
	func testGeneratedPositionsNormalsTexture() throws {
		let material = SimpleMaterial()
		// base is XZ unit plane
		let base = ModelEntity(mesh: .generatePlane(width: 1, depth: 1),materials: [material])
		
		// target0 still XZ, but wider in X axis
		let target = ModelComponent(mesh: .generatePlane(width: 3, depth: 1), materials: [material])
		
		// target1 is a unit plane, but on XY
		let target1 = ModelComponent(mesh: .generatePlane(width: 1, height: 1), materials: [material])
		
		let sut = try MorpherComponent(entity: base, targets: [target, target1])
		let texture = try XCTUnwrap(sut.textureResources.first)
		XCTAssertEqual(texture.vertexCount, 4)
		XCTAssertEqual(texture.resource.width, 4)
		XCTAssertEqual(texture.resource.height, 6) // positions & normals for 3 targets
		
		// target 0
		let positions0 = try texture.getPositions(targetIndex: 0)
		// expect the geometry to expand by 1 unit in each direction on the x-axis
		XCTAssertEqual(positions0, [
			[-1, 0, 0],
			[1, 0, 0],
			[-1, 0, 0],
			[1, 0, 0]
		])
		let normals0 = try texture.getPositions(targetIndex: MorpherConstant.maxTargetCount.rawValue)
		// normals all point up still
		XCTAssertEqual(normals0, Array(repeating: [0, 1, 0], count: 4))
		
		// target 1
		let positions1 = try texture.getPositions(targetIndex: 1)
		// expect geometry to rotate around x-axis
		XCTAssertEqual(positions1, [
			[0.0, -0.5, -0.5],
			[0.0, -0.5, -0.5],
			[0.0, 0.5, 0.5],
			[0.0, 0.5, 0.5]
		])
		let normals1 = try texture.getPositions(targetIndex: MorpherConstant.maxTargetCount.rawValue + 1)
		// normals now point forwards
		XCTAssertEqual(normals1, Array(repeating: [0, 0, 1], count: 4))
		
		// target 2 is blank
		let positions2 = try texture.getPositions(targetIndex: 2)
		XCTAssertEqual(positions2, Array(repeating: .zero, count: 4))
		let normals2 = try texture.getPositions(targetIndex: MorpherConstant.maxTargetCount.rawValue + 2)
		XCTAssertEqual(normals2, Array(repeating: .zero, count: 4))
	}
	
	func testAnimation() throws {
		let material = SimpleMaterial()
		let base = ModelEntity(mesh: .generatePlane(width: 1, depth: 1),materials: [material])
		let target = ModelComponent(mesh: .generatePlane(width: 3, depth: 1), materials: [material])
		var sut = try MorpherComponent(entity: base, targets: [target])
		sut.setTargetWeights([1, 0, 0], animation: MorpherAnimation(duration: 2, mode: .linear))
		sut = try XCTUnwrap(sut.updated(deltaTime: 1))
		XCTAssertEqual(sut.currentWeights, [0.5, 0, 0]) // midpoint of the animation
		sut = try XCTUnwrap(sut.updated(deltaTime: 1))
		XCTAssertEqual(sut.currentWeights, [1, 0, 0]) // end of the animation
		XCTAssertNil(sut.updated(deltaTime: 1)) // no update past the end of the animation
	}
	
	// MARK: - MorpherComponent.Error
	
	func testTargetNotTopologicallyIdentical() throws {
		let material = SimpleMaterial()
		let base = ModelEntity(mesh: .generatePlane(width: 1, depth: 1),materials: [material])
		let target = ModelComponent(mesh: .generatePlane(width: 1, depth: 1, cornerRadius: 0.1), materials: [material])
		do {
			let _ = try MorpherComponent(entity: base, targets: [target])
			XCTFail()
		} catch let error as MorpherComponent.Error {
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
			let _ = try MorpherComponent(entity: base, targets: [targetNoNormals])
			XCTFail()
		} catch let error as MorpherComponent.Error {
			XCTAssertEqual(error, .positionsCountNotEqualToNormalsCount)
		}
	}
	
	func testBaseMeshMissing() throws {
		let base = ModelEntity()
		let material = SimpleMaterial()
		let target = ModelComponent(mesh: .generatePlane(width: 1, depth: 1, cornerRadius: 0.1), materials: [material])
		do {
			let _ = try MorpherComponent(entity: base, targets: [target])
			XCTFail()
		} catch let error as MorpherComponent.Error {
			XCTAssertEqual(error, .missingBaseMesh)
		}
	}
	
	func testTargetMissing() throws {
		let material = SimpleMaterial()
		let base = ModelEntity(mesh: .generatePlane(width: 1, depth: 1),materials: [material])
		do {
			let _ = try MorpherComponent(entity: base, targets: [])
			XCTFail()
		} catch let error as MorpherComponent.Error {
			XCTAssertEqual(error, .invalidNumberOfTargets)
		}
	}
	
	func testTooManyTargets() throws {
		let material = SimpleMaterial()
		let base = ModelEntity(mesh: .generatePlane(width: 1, depth: 1),materials: [material])
		let target = ModelComponent(mesh: .generatePlane(width: 1, depth: 1), materials: [material])
		do {
			let _ = try MorpherComponent(entity: base, targets: [target, target, target, target])
			XCTFail()
		} catch let error as MorpherComponent.Error {
			XCTAssertEqual(error, .invalidNumberOfTargets)
		}
	}
}

extension MorpherComponent.PositionNormalTexture {
	func getPositions(targetIndex: Int) throws -> [SIMD3<Float>] {
		guard let device = MTLCreateSystemDefaultDevice() else { return [] }
		let descriptor = MTLTextureDescriptor.texture2DDescriptor(
			pixelFormat: .rgba16Float,
			width: resource.width,
			height: resource.height,
			mipmapped: false)
		descriptor.usage = .shaderWrite // Required for copy

		guard let texture = device.makeTexture(descriptor: descriptor) else { return [] }
		try resource.copy(to: texture)

		#if os(OSX) // Managed mode exists only in OSX
		if texture.storageMode == .managed {
			// Managed textures need to be synchronized before accessing their data
			guard let commandBuffer = device.makeCommandQueue()?.makeCommandBuffer(),
				  let blitEncoder = commandBuffer.makeBlitCommandEncoder()
			else { return }

			blitEncoder.synchronize(resource: texture)
			blitEncoder.endEncoding()
			commandBuffer.commit()
			commandBuffer.waitUntilCompleted()
		}
		#endif

		// Getting raw pixel bytes
		let bytesPerRow = 8 * texture.width
		var elements = [SIMD4<Float16>](repeating: .zero, count: texture.width * texture.height)
		elements.withUnsafeMutableBytes { bytesPtr in
			texture.getBytes(
				bytesPtr.baseAddress!,
				bytesPerRow: bytesPerRow,
				from: .init(origin: .init(), size: .init(width: texture.width, height: texture.height, depth: 1)),
				mipmapLevel: 0
			)
		}
		let startIndex = targetIndex * vertexCount
		let endIndex = startIndex + vertexCount
		return elements[startIndex..<endIndex]
			.map { SIMD3<Float>($0.xyz) }
	}
}