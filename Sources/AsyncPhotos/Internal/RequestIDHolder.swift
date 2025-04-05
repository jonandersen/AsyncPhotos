import Photos // Needed for PHImageRequestID

final class RequestIDHolder: @unchecked Sendable {
    var id: PHImageRequestID = PHInvalidImageRequestID
} 