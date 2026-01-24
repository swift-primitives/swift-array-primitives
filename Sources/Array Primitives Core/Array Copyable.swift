//
//  File.swift
//  swift-array-primitives
//
//  Created by Coen ten Thije Boonkkamp on 24/01/2026.
//

// MARK: - Copy-on-Write (package access for cross-module use)

extension Array where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    package mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.copy()
            unsafe (_cachedPtr = _storage.pointer(at: 0))  // CRITICAL: Update cached pointer
        }
    }
}

// MARK: - Copy-on-Write (Copyable elements only)

extension Array where Element: Copyable {
    /// Appends an element to the array (CoW-aware).
    ///
    /// This method shadows the base `append(_:)` when `Element: Copyable`,
    /// providing copy-on-write semantics.
    @inlinable
    public mutating func append(_ element: Element) {
        makeUnique()
        let count = Index.Count.init(__unchecked: _storage.header)
        ensureCapacity(count + 1)
        _storage.initialize(to: element, at: .init(count))
        _storage.header = (count + 1).rawValue
    }

    /// Removes and returns the last element (CoW-aware).
    ///
    /// This method shadows the base `removeLast()` when `Element: Copyable`,
    /// providing copy-on-write semantics.
    @inlinable
    public mutating func removeLast() -> Element? {
        makeUnique()
        let count = _storage.header
        guard count > 0 else { return nil }
        _storage.header = count - 1
        return _storage.move(at: .init(__unchecked: (), position: count - 1))
    }

    /// Removes all elements from the array (CoW-aware).
    ///
    /// This method shadows the base `removeAll(keepingCapacity:)` when `Element: Copyable`,
    /// providing copy-on-write semantics.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        makeUnique()
        _storage.deinitialize()
        if !keepingCapacity {
            _storage = Array.Storage.create(minimumCapacity: 0)
            unsafe (_cachedPtr = _storage.pointer(at: .zero))
        }
    }
}

extension Array where Element: Copyable {
    /// Accesses the element at the given typed index with copy-on-write semantics.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Index) -> Element {
        get {
            precondition(index.position.rawValue < _storage.header, "Index out of bounds")
            return unsafe _cachedPtr[index.position.rawValue]
        }
        set {
            makeUnique()
            precondition(index.position.rawValue < _storage.header, "Index out of bounds")
            unsafe _cachedPtr[index.position.rawValue] = newValue
        }
    }
}
