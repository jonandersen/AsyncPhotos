# AsyncPhotos

A Swift library that provides modern Swift concurrency wrappers around PHImageManager methods in the Photos framework.

## Features

- Access PHImageManager methods using native Swift concurrency patterns
- Replace callback-based APIs with async/await and AsyncThrowingStream alternatives
- Proper handling of task cancellation through Swift's structured concurrency
- Support for all major PHImageManager functionality:
  - Image loading with progressive quality
  - Video asset handling
  - Live Photo loading
  - Full image data and metadata access

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.5+
- Xcode 14.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/jonandersen/AsyncPhotos.git", from: "0.1.2")
]
```

## Usage

### Basic Usage Pattern

The library adds an `.async` property to PHImageManager that gives you access to async versions of its methods:

```swift
import AsyncPhotos
import Photos

// Get async access to PHImageManager
let asyncImageManager = PHImageManager.default().async

// Use async/await with PHImageManager
do {
    let playerItem = try await asyncImageManager.requestPlayerItem(forVideo: videoAsset, options: options)
    // Use playerItem
} catch {
    // Handle error
}
```

### Working with Images

```swift
import AsyncPhotos
import Photos
import SwiftUI

struct AssetThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?
    
    var body: some View {
        Image(uiImage: image ?? UIImage())
            .resizable()
            .aspectRatio(contentMode: .fill)
            .task {
                do {
                    // Get image progressively with AsyncThrowingStream
                    for try await progressiveImage in PHImageManager.default().async.requestImage(
                        for: asset,
                        targetSize: CGSize(width: 300, height: 300),
                        contentMode: .aspectFill,
                        options: nil
                    ) {
                        // Update the UI with each quality level
                        image = progressiveImage
                    }
                } catch {
                    print("Failed to load image: \(error)")
                }
            }
    }
}
```

### Handling Videos

```swift
import AsyncPhotos
import Photos
import AVKit

func prepareVideoPlayback(for asset: PHAsset) async throws -> AVPlayerItem {
    let options = PHVideoRequestOptions()
    options.deliveryMode = .highQualityFormat
    
    // Use async/await for video request
    return try await PHImageManager.default().async.requestPlayerItem(forVideo: asset, options: options)
}

// Usage with AVKit
let playerItem = try await prepareVideoPlayback(for: videoAsset)
let player = AVPlayer(playerItem: playerItem)
let playerViewController = AVPlayerViewController()
playerViewController.player = player
present(playerViewController, animated: true)
```

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details. 