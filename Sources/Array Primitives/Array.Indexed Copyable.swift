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
public import Array_Primitive
public import Array_Protocol_Primitives
// ============================================================================
// MARK: - Properties
// ============================================================================

extension Array.Indexed where Element: Copyable {
    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _storage.isEmpty }

    /// The current capacity of the array.
    @inlinable
    public var capacity: Index.Count { _storage.capacity.retag(Tag.self) }
}

// ============================================================================
// MARK: - Mutating Operations
// ============================================================================

extension Array.Indexed where Element: Copyable {
    /// Appends an element to the array.
    ///
    /// - Parameter element: The element to append.
    /// - Complexity: O(1) amortized.
    @inlinable
    public mutating func append(_ element: Element) {
        _storage.append(element)
    }

    /// Static primitive for `Collection.Remove.Last`. Use `.remove.last()` at call sites.
    @inlinable
    public static func removeLast(_ base: inout Self) -> Element? {
        Array.removeLast(&base._storage)
    }

    /// Static primitive for `Collection.Clearable`. Use `.remove.all()` at call sites.
    @inlinable
    public static func removeAll(_ base: inout Self) {
        Array.removeAll(&base._storage)
    }
}
