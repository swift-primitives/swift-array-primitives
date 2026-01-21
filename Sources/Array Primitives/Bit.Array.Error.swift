// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Bit_Primitives

// MARK: - Hoisted Error Types
//
// Error types are hoisted to module level for typed throws compatibility.
// Use the typealias (e.g., `Bit.Array.Error`) in your code.

/// Errors that can occur during `Bit.Array` operations.
public enum __BitArrayError: Swift.Error, Sendable, Equatable {
    case bounds(index: Int, count: Int)
    case invalidCount
}

/// Errors that can occur during `Bit.Array.Bounded` operations.
public enum __BitArrayBoundedError: Swift.Error, Sendable, Equatable {
    case bounds(index: Int, count: Int)
    case invalidCount
    case overflow
}

/// Errors that can occur during `Bit.Array.Inline` operations.
public enum __BitArrayInlineError: Swift.Error, Sendable, Equatable {
    case bounds(index: Int, count: Int)
    case overflow
}

// MARK: - Canonical Error Typealiases

extension Bit.Array {
    /// Errors that can occur during packed bit array operations.
    public typealias Error = __BitArrayError
}

extension Bit.Array.Bounded {
    /// Errors that can occur during bounded packed bit array operations.
    public typealias Error = __BitArrayBoundedError
}

extension Bit.Array.Inline {
    /// Errors that can occur during inline packed bit array operations.
    public typealias Error = __BitArrayInlineError
}
