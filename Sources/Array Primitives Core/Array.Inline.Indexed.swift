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

// MARK: - Array.Inline.Indexed

extension Array.Inline where Element: Copyable {
    /// A wrapper providing phantom-typed index access to inline array storage.
    ///
    /// `Indexed<Tag>` wraps an `Array<Element>.Inline<capacity>` and provides subscript
    /// access via `Index<Tag>` instead of raw `Int`, enabling type-safe indexing
    /// where the phantom type differs from the element type.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// enum NodeTag {}
    /// var storage = Array<Payload>.Inline<8>()
    /// try storage.append(payload)
    ///
    /// var indexed = Array<Payload>.Inline<8>.Indexed<NodeTag>(storage)
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
    /// `Array.Inline` is `~Copyable` unconditionally, so `Indexed` is also `~Copyable`.
    public struct Indexed<Tag: ~Copyable>: ~Copyable {
        @usableFromInline
        var _storage: Array<Element>.Inline<capacity>

        /// Creates an indexed wrapper around the given storage.
        ///
        /// - Parameter storage: The inline array to wrap.
        @inlinable
        public init(_ storage: consuming Array<Element>.Inline<capacity>) {
            self._storage = storage
        }

        /// The phantom-typed count for bounds checking.
        ///
        /// Use with `Index<Tag>` for typed bounds checks:
        /// ```swift
        /// guard node < indexed.count else { return }
        /// ```
        @inlinable
        public var count: Index_Primitives.Index<Tag>.Count {
            Index_Primitives.Index<Tag>.Count(__unchecked: _storage.count.rawValue)
        }

        /// Accesses the element at the given phantom-typed index.
        ///
        /// - Parameter index: The typed index of the element to access.
        /// - Precondition: `index` must be within bounds.
        @inlinable
        public subscript(index: Index_Primitives.Index<Tag>) -> Element {
            get {
                precondition(index.position.rawValue < _storage.count.rawValue, "Index out of bounds")
                return unsafe _storage._readPointerToElement(at: index.position.rawValue).pointee
            }
            set {
                precondition(index.position.rawValue < _storage.count.rawValue, "Index out of bounds")
                unsafe _storage._pointerToElement(at: index.position.rawValue).pointee = newValue
            }
        }

        /// Accesses the element at the given bounded index.
        ///
        /// The type `Index<Tag>.Bounded<capacity>` proves `0 <= index < capacity`.
        /// **No runtime bounds check is performed.**
        ///
        /// ## Type-Based Safety
        ///
        /// The TYPE encodes the bounds proof:
        /// - `Index<Tag>` subscript → has runtime bounds check
        /// - `Index<Tag>.Bounded<capacity>` subscript → NO bounds check (type proves it)
        ///
        /// ## Contract
        ///
        /// For full arrays (`count == capacity`), this subscript is completely safe.
        /// For partial arrays (`count < capacity`), caller must ensure `index < count`.
        ///
        /// - Parameter index: A bounded index where the type proves `0 <= index < capacity`.
        @inlinable
        public subscript(_ index: Index_Primitives.Index<Tag>.Bounded<capacity>) -> Element {
            get {
                // Type proves: 0 <= index < capacity
                // For full arrays: count == capacity, so 0 <= index < count ✓
                unsafe _storage._readPointerToElement(at: index.rawValue).pointee
            }
            set {
                unsafe _storage._pointerToElement(at: index.rawValue).pointee = newValue
            }
        }
    }
}

// MARK: - Passthrough Properties

extension Array.Inline.Indexed where Element: Copyable {
    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _storage.isEmpty }

    /// Whether the array is at full capacity.
    @inlinable
    public var isFull: Bool { _storage.isFull }
}

// MARK: - Mutating Operations

extension Array.Inline.Indexed where Element: Copyable {
    /// Appends an element to the array.
    ///
    /// - Parameter element: The element to append.
    /// - Throws: `Array.Inline.Error.overflow` if the array is full.
    @inlinable
    public mutating func append(_ element: Element) throws(Array.Inline.Error) {
        try _storage.append(element)
    }

    /// Removes and returns the last element, or nil if empty.
    ///
    /// - Returns: The removed element, or `nil` if the array is empty.
    @inlinable
    public mutating func removeLast() -> Element? {
        _storage.removeLast()
    }

    /// Removes all elements from the array.
    @inlinable
    public mutating func removeAll() {
        _storage.removeAll()
    }
}

// MARK: - Sendable

extension Array.Inline.Indexed: @unchecked Sendable where Element: Sendable, Tag: ~Copyable {}
