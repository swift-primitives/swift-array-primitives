//
//  File.swift
//  swift-array-primitives
//
//  Created by Coen ten Thije Boonkkamp on 23/01/2026.
//

// MARK: - Error Types (Hoisted to Module Level)

/// Hoisted implementation of ``Array/Inline/Error``.
///
/// Swift does not allow nested types inside generic types to be easily accessed.
/// This error type is hoisted to module level and exposed via typealias.
public enum __ArrayInlineError: Swift.Error, Sendable, Equatable {
    /// The array is full and cannot accept more elements.
    case overflow

    /// The index is out of bounds.
    case indexOutOfBounds(index: Int, count: Int)
}

extension Array.Inline {
    /// Errors that can occur during inline array operations.
    public typealias Error = __ArrayInlineError
}
