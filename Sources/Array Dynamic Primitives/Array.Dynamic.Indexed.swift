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
    /// access via `Index<Tag>` instead of `Index<Element>`, enabling type-safe
    /// indexing where the phantom type differs from the element type.
    public struct Indexed<Tag: Copyable>: Copyable, @unchecked Sendable {
        @usableFromInline
        var _storage: Array<Element>

        public typealias Index = Array<Tag>.Index

        /// Creates an indexed wrapper around the given storage.
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
    @inlinable
    public var count: Index.Count {
        _storage.count.retag(Tag.self)
    }
}

// ============================================================================
// MARK: - Subscripts
// ============================================================================

extension Array.Indexed {
    /// Accesses the element at the given phantom-typed index.
    @inlinable
    public subscript(index: Index) -> Element {
        get {
            let elementIndex = index.retag(Element.self)
            precondition(elementIndex < _storage.count, "Index out of bounds")
            return _storage._buffer[elementIndex]
        }
        set {
            let elementIndex = index.retag(Element.self)
            precondition(elementIndex < _storage.count, "Index out of bounds")
            _storage._buffer[elementIndex] = newValue
        }
    }
}

// ============================================================================
// MARK: - Collection.Protocol Conformance
// ============================================================================

extension Array.Indexed: Collection.`Protocol` {
    @inlinable
    public var startIndex: Index_Primitives.Index<Element> { _storage.startIndex }

    @inlinable
    public var endIndex: Index_Primitives.Index<Element> { _storage.endIndex }

    @inlinable
    public subscript(_ position: Index_Primitives.Index<Element>) -> Element {
        get { _storage[position] }
    }

    @inlinable
    public func index(after i: Index_Primitives.Index<Element>) -> Index_Primitives.Index<Element> {
        _storage.index(after: i)
    }
}

// ============================================================================
// MARK: - Conformance Declarations
// ============================================================================

extension Array.Indexed: Collection.Remove.Last {}
extension Array.Indexed: Collection.Clearable {}
