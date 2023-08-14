#  Reality Morpher

Adds Morph Target / Shape Key / Blend Shape animations to RealityKit

![Cloth simulation animation](/Example/Cloth-simulation.gif)

### Installation

#### Xcode project

From the Xcode menu select `File > Add Package Dependencies...` and enter `https://github.com/Utsira/RealityMorpher`

#### SPM Package

Add RealityMorpher as a dependency in the `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/Utsira/RealityMorpher.git", .upToNextMajor(from: "0.0.1"))
]
```

### Documentation

From the Xcode menu select `Product > Build Documentation` to view the documentation.

### Requirements

Minimum iOS 15 or macOS 12. 
Keyframe animation features require iOS 17 or macOS 14.
Not compatible with visionOS because it uses `CustomMaterial`.

### To-do

- Update boundsMargin on the base ModelComponent
