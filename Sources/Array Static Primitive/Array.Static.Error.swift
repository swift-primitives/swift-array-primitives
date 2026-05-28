//
//  File.swift
//  swift-array-primitives
//
//  Created by Coen ten Thije Boonkkamp on 23/01/2026.
//

// MARK: - Error Types (Hoisted to Module Level)

public import Array_Primitive

extension Array.Static {
    /// Errors that can occur during static array operations.
    public typealias Error = __ArrayStaticError
}

/// Hoisted implementation of ``Array/Static/Error``.
///
/// Swift does not allow nested types inside generic types to be easily accessed.
/// This error type is hoisted to module level and exposed via typealias.
public enum __ArrayStaticError: Swift.Error, Sendable, Equatable {
    /// The array is full and cannot accept more elements.
    case overflow

    /// The index is out of bounds.
    case indexOutOfBounds(index: Int, count: Int)
}
