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
// MARK: - Subscripts (Copyable with CoW)
// ============================================================================

// Copy-on-Write is now handled internally by Buffer.Linear.
// No manual makeUnique() needed at the Array level.

extension Array where Element: Copyable {
    /// Accesses the element at the given typed index with copy-on-write semantics.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Index) -> Element {
        get {
            precondition(index < count, "Index out of bounds")
            return _buffer[index]
        }
        set {
            precondition(index < count, "Index out of bounds")
            _buffer[index] = newValue
        }
    }
}

// ============================================================================
// MARK: - Element Access
// ============================================================================

extension Array where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    @inlinable
    public func element(at index: Index) -> Element? {
        guard index < count else { return nil }
        return _buffer[index]
    }

    /// Returns element at index offset from given base index.
    @inlinable
    public func element(
        at base: Index,
        offsetBy offset: Index.Offset
    ) -> Element? {
        guard let newIndex = try? (base + offset) else { return nil }
        guard newIndex < count else { return nil }
        return _buffer[newIndex]
    }
}

// ============================================================================
// MARK: - Mutating Operations (CoW)
// ============================================================================

extension Array where Element: Copyable {
    /// Appends an element to the array (CoW-aware).
    @inlinable
    public mutating func append(_ element: Element) {
        _buffer.append(element)
    }

    /// Removes and returns the last element (CoW-aware).
    @inlinable
    public mutating func removeLast() -> Element? {
        guard !_buffer.isEmpty else { return nil }
        return _buffer.removeLast()
    }

    /// Removes all elements from the array (CoW-aware).
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        _buffer.removeAll()
        if !keepingCapacity {
            _buffer = Buffer<Element>.Linear(minimumCapacity: .zero)
        }
    }
}

// ============================================================================
// MARK: - Property View Operations
// ============================================================================

extension Property.View.Typed
where Tag == Sequence.ForEach, Base == Array<Element>, Element: Copyable {
    /// Consuming iteration: `.forEach.consuming { }`
    @_lifetime(&self)
    @inlinable
    public mutating func consuming(_ body: (Element) -> Void) {
        while unsafe !base.pointee._buffer.isEmpty {
            body(unsafe base.pointee._buffer.consumeFront())
        }
    }
}
