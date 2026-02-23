//// ===----------------------------------------------------------------------===//
////
//// This source file is part of the swift-primitives open source project
////
//// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
//// Licensed under Apache License v2.0
////
//// See LICENSE for license information
////
//// ===----------------------------------------------------------------------===//
//
//public import Index_Primitives
//public import Array_Primitives_Core
//
//// ============================================================================
//// MARK: - Array.Static.Indexed Definition
//// ============================================================================
//
//extension Array.Static where Element: ~Copyable {
//    /// A wrapper providing phantom-typed index access to static array storage.
//    ///
//    /// `Indexed<Tag>` wraps an `Array<Element>.Static<capacity>` and provides subscript
//    /// access via `Index<Tag>` instead of the element-typed index, enabling type-safe
//    /// indexing where the phantom type differs from the element type.
//    public struct Indexed<Tag: ~Copyable>: ~Copyable {
//        @usableFromInline
//        var storage: Array_Primitives_Core.Array<Element>.Static<capacity>
//
//        /// Creates an indexed wrapper around the given storage.
//        @inlinable
//        public init(_ storage: consuming Array_Primitives_Core.Array<Element>.Static<capacity>) {
//            self.storage = storage
//        }
//
//        /// The phantom-typed count for bounds checking.
//        @inlinable
//        public var count: Index_Primitives.Index<Tag>.Count {
//            storage.count.retag(Tag.self)
//        }
//    }
//}
//
//// ============================================================================
//// MARK: - Properties
//// ============================================================================
//
//extension Array.Static.Indexed where Element: ~Copyable {
//    /// Whether the array is empty.
//    @inlinable
//    public var isEmpty: Bool { storage.isEmpty }
//
//    /// Whether the array is at full capacity.
//    @inlinable
//    public var isFull: Bool { storage.isFull }
//}
//
//// ============================================================================
//// MARK: - Typed Subscript (~Copyable)
//// ============================================================================
//
//extension Array.Static.Indexed where Element: ~Copyable {
//    /// Accesses the element at the given phantom-typed index.
//    @inlinable
//    public subscript(index: Index_Primitives.Index<Tag>) -> Element {
//        _read {
//            yield storage[index.retag(Element.self)]
//        }
//        _modify {
//            yield &storage[index.retag(Element.self)]
//        }
//    }
//}
//
//// ============================================================================
//// MARK: - Borrowed Element Access (for ~Copyable elements)
//// ============================================================================
//
//extension Array.Static.Indexed where Element: ~Copyable {
//    /// Accesses the element at the given index via closure (for ~Copyable elements).
//    @inlinable
//    public func withElement<R>(at index: Index_Primitives.Index<Tag>, _ body: (borrowing Element) -> R) -> R {
//        storage.withElement(at: index.retag(Element.self), body)
//    }
//}
//
//// ============================================================================
//// MARK: - Collection.Protocol Conformance
//// ============================================================================
//
//extension Array.Static.Indexed: Collection.`Protocol` where Element: ~Copyable {
//    @inlinable
//    public var startIndex: Index_Primitives.Index<Element> { storage.startIndex }
//
//    @inlinable
//    public var endIndex: Index_Primitives.Index<Element> { storage.endIndex }
//
//    @inlinable
//    public subscript(_ position: Index_Primitives.Index<Element>) -> Element {
//        _read { yield storage[position] }
//    }
//
//    @inlinable
//    public func index(after i: Index_Primitives.Index<Element>) -> Index_Primitives.Index<Element> {
//        storage.index(after: i)
//    }
//}
//
//// ============================================================================
//// MARK: - Mutating Operations
//// ============================================================================
//
//extension Array.Static.Indexed where Element: ~Copyable {
//    /// Appends an element to the array.
//    ///
//    /// - Parameter element: The element to append.
//    /// - Throws: `Array.Static.Error.overflow` if the array is full.
//    @inlinable
//    public mutating func append(_ element: consuming Element) throws(Array.Static.Error) {
//        try storage.append(element)
//    }
//
//    /// Static primitive for `Collection.Remove.Last`. Use `.remove.last()` at call sites.
//    @inlinable
//    public static func removeLast(_ base: inout Self) -> Element? {
//        Array.Static.removeLast(&base.storage)
//    }
//
//    /// Static primitive for `Collection.Clearable`. Use `.remove.all()` at call sites.
//    @inlinable
//    public static func removeAll(_ base: inout Self) {
//        Array.Static.removeAll(&base.storage)
//    }
//}
