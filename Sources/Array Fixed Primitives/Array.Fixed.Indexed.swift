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

import Index_Primitives
public import Array_Primitives_Core

// MARK: - Array.Fixed.Indexed

extension Array.Fixed {
    /// A wrapper providing phantom-typed index access to bounded array storage.
    ///
    /// `Indexed<Tag>` wraps an `Array<Element>.Bounded` and provides subscript
    /// access via `Index<Tag>` instead of raw `Int`, enabling type-safe indexing
    /// where the phantom type differs from the element type.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// enum NodeTag {}
    /// let storage = try Array<Payload>.Bounded(count: 10) { index in
    ///     Payload(id: index)
    /// }
    ///
    /// var indexed = Array<Payload>.Bounded.Indexed<NodeTag>(storage)
    /// let node: Index<NodeTag> = .zero
    /// indexed[node]  // Access via typed index
    /// guard node < indexed.count else { return }  // Typed bounds check
    /// ```
    ///
    /// ## Design
    ///
    /// This follows the `Property.Typed` pattern: the nested type "smuggles" the
    /// `Tag` generic parameter into scope, allowing typed operations without
    /// requiring protocols (which can't have `~Copyable` associated types).
    ///
    /// ## Note
    ///
    /// `Array.Fixed` is `~Copyable` unconditionally, so `Indexed` is also `~Copyable`.
    public struct Indexed<Tag: ~Copyable>: ~Copyable {
        @usableFromInline
        var _storage: Array<Element>.Fixed

        /// Creates an indexed wrapper around the given storage.
        ///
        /// - Parameter storage: The bounded array to wrap.
        @inlinable
        public init(_ storage: consuming Array<Element>.Fixed) {
            self._storage = storage
        }

        /// The phantom-typed count for bounds checking.
        ///
        /// Use with `Index<Tag>` for typed bounds checks:
        /// ```swift
        /// guard node < indexed.count else { return }
        /// ```
        @inlinable
        public var count: Index.Count {
            Index.Count(__unchecked: _storage.count.rawValue)
        }

        /// Accesses the element at the given phantom-typed index.
        ///
        /// - Parameter index: The typed index of the element to access.
        /// - Precondition: `index` must be within bounds.
        @inlinable
        public subscript(index: Index) -> Element {
            _read {
                precondition(index.position.rawValue < _storage.count.rawValue, "Index out of bounds")
                yield unsafe _storage._cachedPtr[index.position.rawValue]
            }
            _modify {
                precondition(index.position.rawValue < _storage.count.rawValue, "Index out of bounds")
                yield &(unsafe _storage._cachedPtr[index.position.rawValue])
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




