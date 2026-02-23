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

public import Index_Primitives
public import Array_Primitives_Core
public import Buffer_Linear_Small_Primitives

extension Array where Element: ~Copyable {

    // MARK: - Small (SmallVec Pattern)

    /// An array with small-buffer optimization (SmallVec pattern).
    ///
    /// `Array.Small` stores up to `inlineCapacity` elements in inline storage,
    /// then automatically spills to heap storage when that capacity is exceeded.
    ///
    /// - Note: This type is declared inside `Array` (not in an extension) due to a
    ///   Swift compiler bug. Public API is in the Array Small Primitives module.
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {

        /// Internal small linear buffer.
        ///
        /// Delegates growth, spill, element lifecycle, and span access
        /// to `Buffer<Element>.Linear.Small` from buffer-primitives.
        @usableFromInline
        package var _buffer: Buffer<Element>.Linear.Small<inlineCapacity>

        /// Creates an empty small array.
        @inlinable
        public init() {
            self._buffer = .init()
        }
    }
}
