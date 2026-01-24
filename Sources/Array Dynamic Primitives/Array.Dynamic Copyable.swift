//
//  File.swift
//  swift-array-primitives
//
//  Created by Coen ten Thije Boonkkamp on 24/01/2026.
//

public import Array_Primitives_Core

// MARK: - Copy-on-Write (package access for cross-module use)

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

// MARK: - Copy-on-Write (Copyable elements only)

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

extension Array: Collection.`Protocol` where Element: Copyable {}

// MARK: - Iterator

extension Array where Element: Copyable {
    /// Pointer-based iterator for Array.
    ///
    /// Zero-copy iteration using typed `Index<Element>` for position tracking.
    /// The iterator holds a pointer to the storage, not a copy of the elements.
    ///
    /// ## Safety
    ///
    /// The iterator is only valid while the source array exists and is not mutated.
    /// This matches the semantics of stdlib's Array.Iterator.
    @safe
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let base: UnsafePointer<Element>

        @usableFromInline
        let end: Index.Count

        @usableFromInline
        var position: Index

        @usableFromInline @unsafe
        init(base: UnsafePointer<Element>, count: Index.Count) {
            unsafe self.base = base
            self.end = count
            self.position = .zero
        }

        @inlinable
        public mutating func next() -> Element? {
            guard position < end else { return nil }
            let result = unsafe base[position]
            position = (position + 1)!
            return result
        }
    }
}

extension Array.Iterator: @unchecked Sendable where Element: Sendable {}

extension Array: Collection.Access.Random where Element: Copyable {}

// MARK: - ForEach: Consuming Operations (Copyable only)

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

extension Array: Sequence.`Protocol` where Element: Copyable {
    /// Returns a pointer-based iterator over the array elements.
    ///
    /// Zero-copy iteration - no allocation, no element copying.
    /// Uses typed `Index<Element>` for position tracking.
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        unsafe Iterator(base: UnsafePointer(_cachedPtr), count: .init(__unchecked: count.rawValue))
    }
}
