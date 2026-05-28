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

public import Buffer_Linear_Inline_Primitives

public import Array_Primitive

extension Array where Element: ~Copyable {

    // MARK: - Static (Fixed-Capacity, Inline Storage)

    /// A fixed-capacity vector with inline storage (static_vector / ArrayVec).
    ///
    /// `Array.Static` stores elements directly within the struct's memory layout,
    /// requiring no heap allocation. The capacity is specified as a compile-time
    /// generic parameter. Count varies from 0 to capacity.
    ///
    /// ## Move-Only
    ///
    /// `Array.Static` is unconditionally `~Copyable` due to its deinitializer requirement.
    /// Both the array and its elements can be move-only types.
    ///
    /// ## Limitations
    ///
    /// - Maximum element stride: 64 bytes (8 Int-sized words)
    /// - Element alignment must not exceed `MemoryLayout<Int>.alignment`
    /// - Capacity is fixed at compile time; use `Array.Small` for flexible sizing
    /// Element cleanup is handled by `Storage.Inline`'s deinit.
    // `@frozen` permits the partial consume of `_buffer` in the consuming
    // `Sequenceable.makeIterator()` (ops module), mirroring buffer-linear.
    @frozen
    public struct Static<let capacity: Int>: ~Copyable {
        /// Internal inline linear buffer.
        @usableFromInline
        package var _buffer: Buffer<Element>.Linear.Inline<capacity>

        /// Creates an empty inline array.
        @inlinable
        public init() {
            self._buffer = Buffer<Element>.Linear.Inline<capacity>()
        }
    }
}

// MARK: - Sendable

extension Array.Static: @unchecked Sendable where Element: Sendable {}
