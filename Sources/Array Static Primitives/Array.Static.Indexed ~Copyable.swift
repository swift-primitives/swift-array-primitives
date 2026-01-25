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

// ============================================================================
// MARK: - Array.Static.Indexed Definition
// ============================================================================

extension Array.Static where Element: ~Copyable {
    /// A wrapper providing phantom-typed index access to static array storage.
    ///
    /// `Indexed<Tag>` wraps an `Array<Element>.Static<capacity>` and provides subscript
    /// access via `Index<Tag>` instead of the element-typed index, enabling type-safe
    /// indexing where the phantom type differs from the element type.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// enum NodeTag {}
    /// var storage = Array<Payload>.Static<8>()
    /// try storage.append(payload)
    ///
    /// var indexed = Array<Payload>.Static<8>.Indexed<NodeTag>(storage)
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
    /// `Array.Static` is `~Copyable` unconditionally, so `Indexed` is also `~Copyable`.
    public struct Indexed<Tag: ~Copyable>: ~Copyable {
        @usableFromInline
        var storage: Array<Element>.Static<capacity>

        /// Creates an indexed wrapper around the given storage.
        ///
        /// - Parameter storage: The static array to wrap.
        @inlinable
        public init(_ storage: consuming Array<Element>.Static<capacity>) {
            self.storage = storage
        }

        /// The phantom-typed count for bounds checking.
        ///
        /// Use with `Index<Tag>` for typed bounds checks:
        /// ```swift
        /// guard node < indexed.count else { return }
        /// ```
        @inlinable
        public var count: Index_Primitives.Index<Tag>.Count {
            Index_Primitives.Index<Tag>.Count(__unchecked: storage.count.rawValue)
        }
    }
}

// ============================================================================
// MARK: - Properties
// ============================================================================

extension Array.Static.Indexed where Element: ~Copyable {
    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { storage.isEmpty }

    /// Whether the array is at full capacity.
    @inlinable
    public var isFull: Bool { storage.isFull }
}

// ============================================================================
// MARK: - Typed Subscript (~Copyable)
// ============================================================================

extension Array.Static.Indexed where Element: ~Copyable {
    /// Accesses the element at the given phantom-typed index.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be within bounds.
    @inlinable
    public subscript(index: Index_Primitives.Index<Tag>) -> Element {
        _read {
            yield storage[index.retag(Element.self)]
        }
        _modify {
            yield &storage[index.retag(Element.self)]
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
        _read {
            yield storage[index.unbounded.retag(Element.self)]
        }
        _modify {
            yield &storage[index.unbounded.retag(Element.self)]
        }
    }
}

// ============================================================================
// MARK: - Borrowed Element Access (for ~Copyable elements)
// ============================================================================

extension Array.Static.Indexed where Element: ~Copyable {
    /// Accesses the element at the given index via closure (for ~Copyable elements).
    ///
    /// - Parameters:
    ///   - index: The phantom-typed index of the element.
    ///   - body: A closure that receives a borrowed reference to the element.
    /// - Returns: The result of the closure.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public func withElement<R>(at index: Index_Primitives.Index<Tag>, _ body: (borrowing Element) -> R) -> R {
        storage.withElement(at: index.retag(Element.self), body)
    }
}

// ============================================================================
// MARK: - Mutating Operations
// ============================================================================

extension Array.Static.Indexed where Element: ~Copyable {
    /// Appends an element to the array.
    ///
    /// - Parameter element: The element to append.
    /// - Throws: `Array.Static.Error.overflow` if the array is full.
    @inlinable
    public mutating func append(_ element: consuming Element) throws(Array.Static.Error) {
        try storage.append(element)
    }

    /// Removes and returns the last element, or nil if empty.
    ///
    /// - Returns: The removed element, or `nil` if the array is empty.
    @inlinable
    public mutating func removeLast() -> Element? {
        storage.removeLast()
    }

    /// Removes all elements from the array.
    @inlinable
    public mutating func removeAll() {
        storage.removeAll()
    }
}
