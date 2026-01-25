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

public import Array_Primitives_Core
import Index_Primitives

// ============================================================================
// MARK: - Array.Indexed Definition
// ============================================================================

extension Array {
    /// A wrapper providing phantom-typed index access to unbounded array storage.
    ///
    /// `Indexed<Tag>` wraps an `Array<Element>` and provides subscript
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
        var _storage: Array<Element>

        public typealias Index = Array<Tag>.Index

        /// Creates an indexed wrapper around the given storage.
        ///
        /// - Parameter storage: The unbounded array to wrap.
        @inlinable
        public init(_ storage: consuming Array<Element>) {
            self._storage = storage
        }
    }
}

// ============================================================================
// MARK: - Properties
// ============================================================================

extension Array.Indexed {
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
}

// ============================================================================
// MARK: - Subscripts
// ============================================================================

extension Array.Indexed {
    /// Accesses the element at the given phantom-typed index.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be within bounds.
    @inlinable
    public subscript(index: Index) -> Element {
        get {
            precondition(index.position.rawValue < _storage.count.rawValue, "Index out of bounds")
            return unsafe _storage.storage.read(at: index.retag(Element.self)).pointee
        }
        set {
            precondition(index.position.rawValue < _storage.count.rawValue, "Index out of bounds")
            _storage.makeUnique()
            _ = _storage.storage.move(at: index.retag(Element.self))
            _storage.storage.initialize(to: newValue, at: index.retag(Element.self))
        }
    }
}
