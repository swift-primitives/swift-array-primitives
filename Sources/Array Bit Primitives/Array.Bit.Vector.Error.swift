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
// Use the typealias (e.g., `Array<Bit>.Vector.Error`) in your code.

/// Errors that can occur during `Array<Bit>.Vector` operations.
public enum __ArrayBitVectorError: Swift.Error, Sendable, Equatable {
    case bounds(index: Bit.Index, count: Bit.Index.Count)
    case invalidCount
}

/// Errors that can occur during `Array<Bit>.Vector.Fixed` operations.
public enum __ArrayBitVectorFixedError: Swift.Error, Sendable, Equatable {
    case bounds(index: Bit.Index, count: Bit.Index.Count)
    case invalidCount
    case overflow
}

/// Errors that can occur during `Array<Bit>.Vector.Inline` operations.
public enum __ArrayBitVectorInlineError: Swift.Error, Sendable, Equatable {
    case bounds(index: Bit.Index, count: Bit.Index.Count)
    case overflow
}

// MARK: - Canonical Error Typealiases

extension Array<Bit>.Vector {
    /// Errors that can occur during bit vector operations.
    public typealias Error = __ArrayBitVectorError
}
