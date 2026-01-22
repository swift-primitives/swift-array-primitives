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

// MARK: - Array.Unbounded.Indexed

extension Array.Unbounded where Element: Copyable {
    /// A wrapper providing phantom-typed index access to unbounded array storage.
    ///
    /// `Indexed<Tag>` wraps an `Array<Element>.Unbounded<N>` and provides subscript
    /// access via `Index<Tag>` instead of raw `Int`, enabling type-safe indexing
    /// where the phantom type differs from the element type.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// enum NodeTag {}
    /// var storage = Array<Payload>.Unbounded<4>()
    /// storage.append(payload)
    ///
    /// var indexed = Array<Payload>.Unbounded<4>.Indexed<NodeTag>(storage)
    /// let node: Index<NodeTag> = .zero
    /// indexed[node]  // Access via typed index
    /// guard node < indexed.count else { return }  // Typed bounds check
    /// ```
    ///
    /// ## Type Safety
    ///
    /// The phantom `Tag` type prevents mixing indices from different domains:
    ///
    /// ```swift
    /// enum GraphA {}
    /// enum GraphB {}
    ///
    /// var storageA: Array<String>.Unbounded<4>.Indexed<GraphA> = ...
    /// let nodeB: Index<GraphB> = .zero
    /// // storageA[nodeB]  // Compile error: cannot convert Index<GraphB> to Index<GraphA>
    /// ```
    ///
    /// ## Design
    ///
    /// This follows the `Property.Typed` pattern: the nested type "smuggles" the
    /// `Tag` generic parameter into scope, allowing typed operations without
    /// requiring protocols (which can't have `~Copyable` associated types).
    public struct Indexed<Tag: Copyable>: Copyable, @unchecked Sendable {
        @usableFromInline
        var _storage: Array<Element>.Unbounded<N>

        /// Creates an indexed wrapper around the given storage.
        ///
        /// - Parameter storage: The unbounded array to wrap.
        @inlinable
        public init(_ storage: consuming Array<Element>.Unbounded<N>) {
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
            Index_Primitives.Index<Tag>.Count(__unchecked: _storage.count)
        }

        /// Accesses the element at the given phantom-typed index.
        ///
        /// - Parameter index: The typed index of the element to access.
        /// - Precondition: `index` must be within bounds.
        @inlinable
        public subscript(index: Index_Primitives.Index<Tag>) -> Element {
            get { _storage[index.position.rawValue] }
            set { _storage[index.position.rawValue] = newValue }
        }
    }
}

// MARK: - Passthrough Properties

extension Array.Unbounded.Indexed where Element: Copyable {
    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _storage.isEmpty }

    /// The current capacity of the array.
    @inlinable
    public var capacity: Int { _storage.capacity }
}

// MARK: - Mutating Operations

extension Array.Unbounded.Indexed where Element: Copyable {
    /// Appends an element to the array.
    ///
    /// - Parameter element: The element to append.
    /// - Complexity: O(1) amortized.
    @inlinable
    public mutating func append(_ element: Element) {
        _storage.append(element)
    }

    /// Removes and returns the last element, or nil if empty.
    ///
    /// - Returns: The removed element, or `nil` if the array is empty.
    /// - Complexity: O(1).
    @inlinable
    public mutating func removeLast() -> Element? {
        _storage.removeLast()
    }

    /// Removes all elements from the array.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current capacity.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        _storage.removeAll(keepingCapacity: keepingCapacity)
    }
}
