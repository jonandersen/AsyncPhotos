import Foundation
import Photos
import UIKit
import AVFoundation
import PhotosUI

enum AsyncPhotosError : Error {
    case unknownError
}

public extension PHImageManager {
    var async: Async<PHImageManager> { .init(self) }
}

// Declare that Async<PHImageManager> is safe to send across concurrency domains
// because PHImageManager is thread-safe.
extension Async: @unchecked Sendable where Wrapped: PHImageManager {}

public extension Async where Wrapped: PHImageManager {
    
    func requestPlayerItem(forVideo asset: PHAsset, options: PHVideoRequestOptions?) async throws -> AVPlayerItem {
        let idHolder = RequestIDHolder()
        
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let currentRequestID = wrapped.requestPlayerItem(forVideo: asset, options: options) { playerItem, info in
                    if let error = info?[PHImageErrorKey] as? Error {
                        continuation.resume(throwing: error)
                        return
                    }
                    if info?[PHImageCancelledKey] as? Bool == true {
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    
                    guard let playerItem = playerItem else {
                        continuation.resume(throwing: AsyncPhotosError.unknownError)
                        return
                    }
                    
                    continuation.resume(returning: playerItem)
                }
                idHolder.id = currentRequestID
            }
        } onCancel: {
            let idToCancel = idHolder.id
            if idToCancel != PHInvalidImageRequestID {
                self.wrapped.cancelImageRequest(idToCancel)
            }
        }
    }
    
    func requestImage(for asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode, options: PHImageRequestOptions?) -> AsyncThrowingStream<UIImage, Error> {
        return AsyncThrowingStream { continuation in
            let requestID = wrapped.requestImage(for: asset, targetSize: targetSize, contentMode: contentMode, options: options) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.finish(throwing: error)
                    return
                }
                
                if info?[PHImageCancelledKey] as? Bool == true {
                    continuation.finish(throwing: CancellationError())
                    return
                }
                
                
                guard let image = image else {
                    // This should in theory not happen.
                    return
                }
                
                if info?[PHImageResultIsDegradedKey] as? Bool == true {
                    // When degraded image is provided, the completion handler will be called again.
                }
                
                continuation.yield(image)
            }
            continuation.onTermination = {@Sendable termination in
                switch termination {
                case .cancelled:
                    // This handles Task.cancel() or the consumer stopping iteration.
                    self.wrapped.cancelImageRequest(requestID)
                default:
                    break
                }
            }
        }
    }
    
    func requestImageDataAndOrientation(for asset: PHAsset, options: PHImageRequestOptions?) -> AsyncThrowingStream<(data: Data, dataUTI: String, orientation: CGImagePropertyOrientation), Error> {
        return AsyncThrowingStream { continuation in
            let requestID = wrapped.requestImageDataAndOrientation(for: asset, options: options) { data, dataUTI, orientation, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.finish(throwing: error)
                    return
                }
                
                if info?[PHImageCancelledKey] as? Bool == true {
                    // This indicates explicit cancellation via cancelImageRequest, not Task cancellation.
                    // The stream should finish throwing CancellationError() here.
                    continuation.finish(throwing: CancellationError())
                    return
                }
                
                guard let data = data, let dataUTI = dataUTI else {
                    // If data is nil, but no error, it might be the end of a sequence?
                    // However, the docs suggest data should generally be non-nil on success.
                    // Finishing without yielding might be okay if a final result was already yielded.
                    // If this is the *first* call and data is nil without error, it's ambiguous.
                    // Let's throw an error for now if data is nil unexpectedly.
                    continuation.finish(throwing: AsyncPhotosError.unknownError)
                    return
                }
                
                continuation.yield((data: data, dataUTI: dataUTI, orientation: orientation))
                
                // Check if this is the final result. If the key is absent or false, it's final.
                let isFinalResult = info?[PHImageResultIsDegradedKey] as? Bool == false
                if isFinalResult {
                    continuation.finish()
                }
                // If it's degraded (true), we just yielded and wait for the next call.
            }
            
            continuation.onTermination = { @Sendable termination in
                switch termination {
                case .cancelled:
                    // This handles Task.cancel() or the consumer stopping iteration.
                    self.wrapped.cancelImageRequest(requestID)
                default:
                    break
                }
            }
        }
    }
    
    func requestAVAsset(forVideo asset: PHAsset, options: PHVideoRequestOptions?) async throws -> (AVAsset, AVAudioMix?) {
        let idHolder = RequestIDHolder()
        
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                // Initiate the request and synchronously get the ID
                let currentRequestID = wrapped.requestAVAsset(forVideo: asset, options: options) { avAsset, audioMix, info in
                    
                    if let error = info?[PHImageErrorKey] as? Error {
                        continuation.resume(throwing: error)
                        return
                    }
                    if info?[PHImageCancelledKey] as? Bool == true { // Explicit cancellation via ID
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    if let finalAsset = avAsset {
                        let uncheckedSendable = UncheckedSendable((finalAsset, audioMix))
                        continuation.resume(returning: uncheckedSendable.unwrap)
                    }
                    
                } 
                
                // Store the synchronously obtained ID in the holder
                idHolder.id = currentRequestID.
            }
        } onCancel: {
            // Read the ID from the holder. This is safe because the assignment happened before the await.
            let idToCancel = idHolder.id
            if idToCancel != PHInvalidImageRequestID {
                // Use self.wrapped explicitly in @Sendable closure
                self.wrapped.cancelImageRequest(idToCancel)
            }
        }
    }
    
    func requestLivePhoto(for asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode, options: PHLivePhotoRequestOptions?) -> AsyncThrowingStream<PHLivePhoto, Error> {
        return AsyncThrowingStream { continuation in
            let requestID = wrapped.requestLivePhoto(for: asset, targetSize: targetSize, contentMode: contentMode, options: options) { livePhoto, info in
                // Error Check
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.finish(throwing: error)
                    return
                }
                // Explicit Cancellation Check
                if info?[PHImageCancelledKey] as? Bool == true {
                    continuation.finish(throwing: CancellationError())
                    return
                }
                
                guard let livePhoto = livePhoto else {
                    // If nil and no error, this might be unexpected unless it's the final call after a degraded one?
                    // For safety, throw if nil without error, unless we know a degraded version was already sent.
                    // We'll rely on the isFinalResult check below.
                    // If it's not final and photo is nil, maybe error? Assume finish for now.
                    continuation.finish(throwing: AsyncPhotosError.unknownError)
                    return
                }
                
                let uncheckedSendable = UncheckedSendable(livePhoto)
                continuation.yield(uncheckedSendable.unwrap)
                
                // Check if final result
                let isFinalResult = info?[PHImageResultIsDegradedKey] as? Bool == false
                if isFinalResult {
                    continuation.finish()
                }
            }
            
            continuation.onTermination = { @Sendable termination in
                if case .cancelled = termination {
                    self.wrapped.cancelImageRequest(requestID)
                }
            }
        }
    }
    
    func requestExportSession(forVideo asset: PHAsset, options: PHVideoRequestOptions?, exportPreset: String) async throws -> AVAssetExportSession {
        let idHolder = RequestIDHolder()
        
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let currentRequestID = wrapped.requestExportSession(forVideo: asset, options: options, exportPreset: exportPreset) { exportSession, info in
                    // Error Check
                    if let error = info?[PHImageErrorKey] as? Error {
                        continuation.resume(throwing: error)
                        return
                    }
                    // Explicit Cancellation Check
                    if info?[PHImageCancelledKey] as? Bool == true {
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    
                    guard let exportSession = exportSession else {
                        continuation.resume(throwing: AsyncPhotosError.unknownError)
                        return
                    }
                    
                    let uncheckedSendable = UncheckedSendable(exportSession)
                    continuation.resume(returning:uncheckedSendable.unwrap)
                }
                idHolder.id = currentRequestID
            }
        } onCancel: {
            let idToCancel = idHolder.id
            if idToCancel != PHInvalidImageRequestID {
                self.wrapped.cancelImageRequest(idToCancel)
            }
        }
    }
}
