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

// MARK: - Array.Fixed.Indexed

extension Array.Fixed {
    /// A wrapper providing phantom-typed index access to bounded array storage.
    ///
    /// `Indexed<Tag>` wraps an `Array<Element>.Fixed` and provides subscript
    /// access via `Index<Tag>` instead of raw `Int`, enabling type-safe indexing
    /// where the phantom type differs from the element type.
    public struct Indexed<Tag: ~Copyable>: ~Copyable {
        @usableFromInline
        var _storage: Array<Element>.Fixed

        /// Creates an indexed wrapper around the given storage.
        @inlinable
        public init(_ storage: consuming Array<Element>.Fixed) {
            self._storage = storage
        }

        /// The phantom-typed count for bounds checking.
        @inlinable
        public var count: Index_Primitives.Index<Tag>.Count {
            _storage.count.retag(Tag.self)
        }

        /// Accesses the element at the given phantom-typed index.
        @inlinable
        public subscript(index: Index_Primitives.Index<Tag>) -> Element {
            _read {
                let elementIndex = index.retag(Element.self)
                precondition(elementIndex < _storage.count, "Index out of bounds")
                yield _storage._buffer[elementIndex]
            }
            _modify {
                let elementIndex = index.retag(Element.self)
                precondition(elementIndex < _storage.count, "Index out of bounds")
                yield &_storage._buffer[elementIndex]
            }
        }
    }
}

// MARK: - Passthrough Properties

extension Array.Fixed.Indexed {
    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _storage.isEmpty }
}
