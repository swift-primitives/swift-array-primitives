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

public import Buffer_Linear_Primitives

extension Array where Element: ~Copyable {

    // MARK: - Bounded (Compile-Time Dimensioned, Heap-Allocated)

    /// A fixed-size array with compile-time dimension and `Algebra.Z<N>` indexing.
    ///
    /// `Array.Bounded<N>` provides compile-time dimension safety: the index type
    /// `Algebra.Z<N>` ensures indices are always within `[0, N)`. Once an index
    /// is constructed (with a bounds check), subscript access is guaranteed safe.
    ///
    /// ## Compile-Time Dimension Safety
    ///
    /// ```swift
    /// let arr = Array<Int>.Bounded<3>([1, 2, 3])
    /// let idx: Array<Int>.Bounded<3>.Index = try! .init(0)  // Bounds-checked
    /// print(arr[idx])  // Safe — no runtime check needed
    /// ```
    ///
    /// ## Type-Level Index Separation
    ///
    /// Indices from different bounded arrays are distinct types:
    /// `Array<Int>.Bounded<3>.Index` ≠ `Array<Int>.Bounded<5>.Index`.
    ///
    /// ## Copy-on-Write
    ///
    /// When `Element` is `Copyable`, uses copy-on-write heap storage.
    @safe
    public struct Bounded<let N: Int>: ~Copyable {
        /// Internal bounded linear buffer.
        @usableFromInline
        package var _buffer: Buffer<Element>.Linear.Bounded

        /// Internal initializer for use by extension modules.
        @usableFromInline
        package init(_buffer: consuming Buffer<Element>.Linear.Bounded) {
            self._buffer = _buffer
        }
    }
}

// MARK: - Conditional Copyable

/// `Array.Bounded` is `Copyable` when its elements are `Copyable`.
extension Array.Bounded: Copyable where Element: Copyable {}

// MARK: - Sendable

extension Array.Bounded: @unchecked Sendable where Element: Sendable {}
