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

// MARK: - Hoisted Error Type
//
// Error type is hoisted to module level for typed throws compatibility.
// Use the typealias (e.g., `Array<T>.Small<N>.Error`) in your code.

/// Errors that can occur during `Array.Small` initialization.
public enum __ArraySmallError: Swift.Error, Sendable, Equatable {
    /// Element stride exceeds inline storage slot size.
    case strideExceedsSlotSize(elementStride: Int, maxSlotSize: Int)

    /// Element alignment exceeds inline storage alignment.
    case alignmentExceedsStorageAlignment(elementAlignment: Int, maxAlignment: Int)
}

// MARK: - Canonical Error Typealias

extension Array.Small where Element: ~Copyable {
    /// Errors that can occur during small array initialization.
    public typealias Error = __ArraySmallError
}
