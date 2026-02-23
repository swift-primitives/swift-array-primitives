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
//// MARK: - Typed Subscript (Copyable)
//// ============================================================================
//
//extension Array.Static.Indexed where Element: Copyable {
//    /// Accesses the element at the given phantom-typed index (copy semantics).
//    ///
//    /// - Parameter index: The typed index of the element to access.
//    /// - Precondition: `index` must be within bounds.
//    @inlinable
//    public subscript(index: Index_Primitives.Index<Tag>) -> Element {
//        get {
//            storage[index.retag(Element.self)]
//        }
//        set {
//            storage[index.retag(Element.self)] = newValue
//        }
//    }
//
//    // Note: Index.Bounded<N> subscript removed - type not yet implemented in index-primitives
//}
//
//// ============================================================================
//// MARK: - Safe Element Access (Copyable elements only)
//// ============================================================================
//
//extension Array.Static.Indexed where Element: Copyable {
//    /// Returns the element at the typed index, or nil if out of bounds.
//    ///
//    /// - Parameter index: The phantom-typed index of the element to access.
//    /// - Returns: The element at the index, or `nil` if out of bounds.
//    @inlinable
//    public func element(at index: Index_Primitives.Index<Tag>) -> Element? {
//        storage.element(at: index.retag(Element.self))
//    }
//}
