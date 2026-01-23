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
public import Array_Primitives_Core

// MARK: - Hoisted Error Types
//
// Error types are hoisted to module level for typed throws compatibility.
// Use the typealias (e.g., `Array<Bit>.Packed.Error`) in your code.

/// Errors that can occur during `Array<Bit>.Packed` operations.
public enum __ArrayBitPackedError: Swift.Error, Sendable, Equatable {
    case bounds(index: Int, count: Int)
    case invalidCount
}

/// Errors that can occur during `Array<Bit>.Packed.Bounded` operations.
public enum __ArrayBitPackedBoundedError: Swift.Error, Sendable, Equatable {
    case bounds(index: Int, count: Int)
    case invalidCount
    case overflow
}

/// Errors that can occur during `Array<Bit>.Packed.Inline` operations.
public enum __ArrayBitPackedInlineError: Swift.Error, Sendable, Equatable {
    case bounds(index: Int, count: Int)
    case overflow
}

// MARK: - Canonical Error Typealiases

extension Array<Bit>.Packed {
    /// Errors that can occur during packed bit array operations.
    public typealias Error = __ArrayBitPackedError
}
