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
public import Storage_Heap_Primitives

public import Array_Primitive

extension Array where Element: ~Copyable {

    // MARK: - Bounded (Compile-Time Dimensioned, Heap-Allocated)

    /// A fixed-size array with compile-time dimension and `Index<Element>.Bounded<N>` indexing.
    ///
    /// `Array.Bounded<N>` provides compile-time dimension safety: the index type
    /// `Index<Element>.Bounded<N>` ensures indices are always within `[0, N)`.
    /// Once an index is constructed (with a bounds check), subscript access is
    /// guaranteed safe.
    ///
    /// ## Type-Level Index Separation
    ///
    /// Indices from different bounded arrays are distinct types:
    /// `Array<Int>.Bounded<3>.Index` ≠ `Array<Int>.Bounded<5>.Index`.
    ///
    /// ## Copy-on-Write
    ///
    /// When `Element` is `Copyable`, uses copy-on-write heap storage.
    // WHY: Category D — structural Sendable workaround; the type is
    // WHY: structurally value-safe but the compiler cannot synthesize
    // WHY: Sendable due to a stored pointer / generic parameter shape.
    @safe
    public struct Bounded<let N: Int>: ~Copyable {
        /// Internal bounded linear buffer.
        @usableFromInline
        package var _buffer: Buffer<Storage<Element>.Heap>.Linear.Bounded

        /// Internal initializer for use by extension modules.
        @usableFromInline
        package init(_buffer: consuming Buffer<Storage<Element>.Heap>.Linear.Bounded) {
            self._buffer = _buffer
        }
    }
}

// MARK: - Conditional Copyable

/// `Array.Bounded` is `Copyable` when its elements are `Copyable`.
extension Array.Bounded: Copyable where Element: Copyable {}

// MARK: - Sendable

extension Array.Bounded: @unchecked Sendable where Element: Sendable {}
