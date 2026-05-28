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

public import Buffer_Linear_Small_Primitives
internal import Index_Primitives

public import Array_Primitive

extension Array where Element: ~Copyable {

    // MARK: - Small (SmallVec Pattern)

    /// An array with small-buffer optimization (SmallVec pattern).
    ///
    /// `Array.Small` stores up to `inlineCapacity` elements in inline storage,
    /// then automatically spills to heap storage when that capacity is exceeded.
    ///
    /// Public API is in the Array Small Primitives module.
    /// Element cleanup is handled by `Storage.Inline`'s deinit (inline path)
    /// or `Storage.Heap`'s deinit (spilled path).
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    @safe
    // `@frozen` permits the partial consume of `_buffer` in the consuming
    // `Sequenceable.makeIterator()` (ops module), mirroring buffer-linear.
    @frozen
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        /// Internal small linear buffer.
        @usableFromInline
        package var _buffer: Buffer<Element>.Linear.Small<inlineCapacity>

        /// Creates an empty small array.
        @inlinable
        public init() {
            self._buffer = .init()
        }
    }
}
