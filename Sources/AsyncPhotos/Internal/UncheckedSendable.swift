struct UncheckedSendable<T>: @unchecked Sendable {
    let unwrap: T
    init(_ value: T) { unwrap = value }
} 