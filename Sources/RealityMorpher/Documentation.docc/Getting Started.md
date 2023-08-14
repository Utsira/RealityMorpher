# Getting Started

Follow these steps to get up and running

## Overview

`RealityMorpher` fully integrates with RealityKit's Entity Component System. The core functionality is encapsulated within ``MorpherComponent``. After registering the component, you instantiate it with some target geometries and attach it to a `ModelEntity`. Use one of the `setTargetWeights` methods, such as ``MorpherComponent/setTargetWeights(_:animation:)``, to animate a transition between the base and one or more of the target geometries.

### Registration

You must call the static registration method ``MorpherComponent/registerComponent()`` on ``MorpherComponent`` before you start using RealityNorpher.

### Adding the Morpher to an Entity

When you instantiate a ``MorpherComponent`` you pass the base Entity you intend to add the component to, as well as an array of the target models: ``MorpherComponent/init(entity:targets:weights:options:)``. After creating the component, you must add it to the base entity:

```swift
MorpherComponent.registerComponent()
do {
	let model = try ModelEntity.loadModel(named: "rock"),
	let target = try ModelEntity.loadModel(named: "rock_shattered").model
	let morpherComponent = try MorpherComponent(entity: model, targets: [target].compactMap { $0 })
	model.components.set(morpherComponent)
} catch {
	// handle errors
}
```

### Blending between Morph Targets

Animate between the different Morph Targets by assigning a weight for each target. Up to 4 weights are passed in a ``MorpherWeights`` object. A weight of 0 means the corresponding target has no influence at all, while a weight of 1.0 means it is fully applied.
- ``MorpherComponent/setTargetWeights(_:animation:)``


