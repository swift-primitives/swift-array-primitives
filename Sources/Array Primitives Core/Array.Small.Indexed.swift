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

// MARK: - Array.Small.Indexed

extension Array.Small where Element: Copyable {
    /// A wrapper providing phantom-typed index access to small array storage.
    ///
    /// `Indexed<Tag>` wraps an `Array<Element>.Small<inlineCapacity>` and provides subscript
    /// access via `Index<Tag>` instead of raw `Int`, enabling type-safe indexing
    /// where the phantom type differs from the element type.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// enum NodeTag {}
    /// var storage = Array<Payload>.Small<4>()
    /// storage.append(payload)
    ///
    /// var indexed = Array<Payload>.Small<4>.Indexed<NodeTag>(storage)
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
    /// `Array.Small` is `~Copyable` unconditionally, so `Indexed` is also `~Copyable`.
    public struct Indexed<Tag: ~Copyable>: ~Copyable {
        @usableFromInline
        var _storage: Array<Element>.Small<inlineCapacity>

        /// Creates an indexed wrapper around the given storage.
        ///
        /// - Parameter storage: The small array to wrap.
        @inlinable
        public init(_ storage: consuming Array<Element>.Small<inlineCapacity>) {
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
                if let heapStorage = _storage._heapStorage {
                    return heapStorage._readElement(at: index.position.rawValue)
                } else {
                    return unsafe _storage._inlineReadPointerToElement(at: index.position.rawValue).pointee
                }
            }
            set {
                precondition(index.position.rawValue < _storage.count.rawValue, "Index out of bounds")
                if _storage._heapStorage != nil {
                    _ = _storage._heapStorage!._moveElement(at: index.position.rawValue)
                    _storage._heapStorage!._initializeElement(at: index.position.rawValue, to: newValue)
                } else {
                    unsafe _storage._inlinePointerToElement(at: index.position.rawValue).pointee = newValue
                }
            }
        }
    }
}

// MARK: - Passthrough Properties

extension Array.Small.Indexed where Element: Copyable {
    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _storage.isEmpty }

    /// The current capacity of the array.
    @inlinable
    public var capacity: Int { _storage.capacity }
}

// MARK: - Mutating Operations

extension Array.Small.Indexed where Element: Copyable {
    /// Appends an element to the array.
    ///
    /// If the array is in inline mode and full, it spills to heap storage first.
    ///
    /// - Parameter element: The element to append.
    @inlinable
    public mutating func append(_ element: Element) {
        _storage.append(element)
    }

    /// Removes and returns the last element, or nil if empty.
    ///
    /// - Returns: The removed element, or `nil` if the array is empty.
    @inlinable
    public mutating func removeLast() -> Element? {
        _storage.removeLast()
    }

    /// Removes all elements from the array.
    ///
    /// - Parameter keepingCapacity: Whether to keep heap storage (if spilled).
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        _storage.removeAll(keepingCapacity: keepingCapacity)
    }
}

// MARK: - Sendable

extension Array.Small.Indexed: @unchecked Sendable where Element: Sendable, Tag: ~Copyable {}
