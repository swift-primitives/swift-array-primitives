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

// ============================================================================
// MARK: - Properties
// ============================================================================

extension Array.Indexed where Element: Copyable {
    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _storage.isEmpty }

    /// The current capacity of the array.
    @inlinable
    public var capacity: Int { _storage.capacity }
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
