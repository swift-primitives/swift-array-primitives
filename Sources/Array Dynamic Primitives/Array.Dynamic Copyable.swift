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
// MARK: - Copy-on-Write
// ============================================================================

extension Array where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    package mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = storage.copy()
            unsafe (_cachedPtr = storage.pointer(at: .zero))  // CRITICAL: Update cached pointer
        }
    }
}

// ============================================================================
// MARK: - Subscripts
// ============================================================================

extension Array where Element: Copyable {
    /// Accesses the element at the given typed index with copy-on-write semantics.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Index) -> Element {
        get {
            precondition(index < count, "Index out of bounds")
            return unsafe _cachedPtr[index]
        }
        set {
            makeUnique()
            precondition(index < count, "Index out of bounds")
            unsafe _cachedPtr[index] = newValue
        }
    }
}

// ============================================================================
// MARK: - Element Access
// ============================================================================

extension Array where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Index) -> Element? {
        guard index < count else { return nil }
        return unsafe _cachedPtr[index]
    }

    /// Returns element at index offset from given base index.
    ///
    /// - Parameters:
    ///   - base: The starting index.
    ///   - offset: The signed offset from the base.
    /// - Returns: The element at the computed position, or `nil` if out of bounds.
    @inlinable
    public func element(
        at base: Index,
        offsetBy offset: Index.Offset
    ) -> Element? {
        guard let newIndex = base + offset else { return nil }
        guard newIndex < count else { return nil }
        return unsafe _cachedPtr[newIndex]
    }
}

// ============================================================================
// MARK: - Mutating Operations (CoW)
// ============================================================================

extension Array where Element: Copyable {
    /// Appends an element to the array (CoW-aware).
    ///
    /// This method shadows the base `append(_:)` when `Element: Copyable`,
    /// providing copy-on-write semantics.
    @inlinable
    public mutating func append(_ element: Element) {
        makeUnique()
        let count = storage.count
        ensureCapacity(count + 1)
        storage.initialize(to: element, at: .init(count))
        storage.header = (count + 1).rawValue
    }

    /// Removes and returns the last element (CoW-aware).
    ///
    /// This method shadows the base `removeLast()` when `Element: Copyable`,
    /// providing copy-on-write semantics.
    @inlinable
    public mutating func removeLast() -> Element? {
        makeUnique()
        let count = storage.header
        guard count > 0 else { return nil }
        storage.header = count - 1
        return storage.move(at: .init(__unchecked: (), position: count - 1))
    }

    /// Removes all elements from the array (CoW-aware).
    ///
    /// This method shadows the base `removeAll(keepingCapacity:)` when `Element: Copyable`,
    /// providing copy-on-write semantics.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        makeUnique()
        storage.deinitialize()
        if !keepingCapacity {
            storage = Array.Storage.create(minimumCapacity: 0)
            unsafe (_cachedPtr = storage.pointer(at: .zero))
        }
    }
}

// ============================================================================
// MARK: - Property View Operations
// ============================================================================

extension Property.View.Typed
where Tag == Sequence.ForEach, Base == Array<Element>, Element: Copyable {
    /// Consuming iteration: `.forEach.consuming { }`
    ///
    /// Iterates over all elements and then clears the array.
    /// Only available for `Copyable` elements.
    ///
    /// - Parameter body: A closure called with each element.
    @_lifetime(&self)
    @inlinable
    public mutating func consuming(_ body: (Element) -> Void) {
        let count = unsafe base.pointee.storage.header
        guard count > 0 else { return }
        unsafe base.pointee.storage.withUnsafeMutablePointerToElements { elements in
            for i in 0..<count {
                unsafe body(elements[i])
            }
        }
        unsafe base.pointee.storage.deinitialize()
    }
}
