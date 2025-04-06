//
//  Async.swift
//  AsyncPhotos
//
//  Created by Jon Andersen on 4/5/25.
//
import Foundation

public struct Async<Wrapped> {
    public let wrapped: Wrapped
    public init(_ wrapped: Wrapped) {
        self.wrapped = wrapped
    }
}

public extension Async where Wrapped == Any {
    init(_ wrapped: Wrapped) {
        self.wrapped = wrapped
    }
}
