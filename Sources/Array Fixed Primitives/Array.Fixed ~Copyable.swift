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
public import Collection_Primitives
public import Index_Primitives
public import Property_Primitives
public import Range_Primitives
public import Sequence_Primitives

// ============================================================================
// MARK: - Collection Protocol Conformances
// ============================================================================

// MARK: - Collection.Protocol Conformance
// Note: Index, startIndex, endIndex, index(after:) defined in Collection.Indexed conformance

extension Array.Fixed: Collection.`Protocol` {}

// MARK: - Collection.Access.Random Conformance
// Note: Collection.Bidirectional conformance is provided below
// for ALL element types (including ~Copyable) via `where Element: ~Copyable`.

extension Array.Fixed: Collection.Access.Random {}

// MARK: - Collection.Indexed Conformance

extension Array.Fixed: Collection.Indexed where Element: ~Copyable {
    public typealias Index = Array<Element>.Index

    @inlinable
    public var startIndex: Index { .zero }

    @inlinable
    public var endIndex: Index { Index(count) }

    @inlinable
    public func index(after i: Index) -> Index { (i + 1)! }
}

// MARK: - Collection.Bidirectional Conformance

extension Array.Fixed: Collection.Bidirectional where Element: ~Copyable {
    @inlinable
    public func index(before i: Index) -> Index { (i - 1)! }
}

// ============================================================================
// MARK: - Sequence Protocol Conformances
// ============================================================================

// MARK: - Iterator

extension Array.Fixed {
    /// Pointer-based iterator for Array.Fixed.
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
        let base: Pointer<Element>

        @usableFromInline
        let end: Index.Count

        @usableFromInline
        var index: Index

        @usableFromInline @unsafe
        init(base: Pointer<Element>, count: Index.Count) {
            unsafe self.base = base
            self.end = count
            self.index = .zero
        }

        @inlinable
        public mutating func next() -> Element? {
            guard index < end else { return nil }
            let result = unsafe base[index]
            index = (index + 1)!
            return result
        }
    }
}

extension Array.Fixed.Iterator: @unchecked Sendable where Element: Sendable {}

// MARK: - Sequence.Protocol Conformance

extension Array.Fixed: Sequence.`Protocol` {
    /// Returns a pointer-based iterator over the array elements.
    ///
    /// Zero-copy iteration - no allocation, no element copying.
    /// Uses typed `Index<Element>` for position tracking.
    @inlinable
    public borrowing func makeIterator() -> Array.Fixed.Iterator {
        guard count.rawValue > 0 else {
            // Empty array - pointer is irrelevant, count is zero
            return unsafe Iterator(base: Pointer(UnsafePointer<Element>(bitPattern: 1)!), count: .zero)
        }
        return unsafe Iterator(base: _cachedPtr.immutable, count: .init(__unchecked: count.rawValue))
    }
}

// ============================================================================
// MARK: - ForEach Property View
// ============================================================================

extension Array.Fixed where Element: ~Copyable {
    /// Property view for iteration operations.
    ///
    /// Provides iteration patterns for ALL element types including `~Copyable`:
    /// - `.forEach { }` — Borrowing iteration via `callAsFunction`
    /// - `.forEach.borrowing { }` — Explicit borrowing iteration
    ///
    /// ## Note
    ///
    /// `Array.Fixed` has a fixed count (immutable), so `.forEach.consuming { }` and
    /// `.drain { }` are not available. Use `Array` or `Array.Small` for
    /// mutable-count arrays.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let array = Array<Int>.Bounded(capacity: 8)
    /// // ... initialize with elements ...
    ///
    /// // Borrowing iteration (works for ALL elements)
    /// array.forEach { print($0) }
    /// ```
    @inlinable
    public var forEach: Property<Sequence.ForEach, Self>.View.Typed<Element> {
        mutating _read {
            yield unsafe Property<Sequence.ForEach, Self>.View.Typed<Element>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.ForEach, Self>.View.Typed<Element>(&self)
            yield &view
        }
    }
}

// MARK: - ForEach: Borrowing Operations (~Copyable)

extension Property.View.Typed
where Tag == Sequence.ForEach, Base == Array<Element>.Fixed, Element: ~Copyable {
    /// Borrowing iteration: `.forEach { }`
    ///
    /// Iterates over all elements without consuming them.
    /// Works for ALL element types including `~Copyable`.
    ///
    /// - Parameter body: A closure called with each borrowed element.
    @inlinable
    public func callAsFunction(_ body: (borrowing Element) -> Void) {
        let count = unsafe base.pointee.count
        (0..<count).forEach { i in
            unsafe body(base.pointee._cachedPtr[i])
        }
    }

    /// Explicit borrowing iteration: `.forEach.borrowing { }`
    ///
    /// Same as `callAsFunction`, but with explicit naming for clarity.
    /// Works for ALL element types including `~Copyable`.
    ///
    /// - Parameter body: A closure called with each borrowed element.
    @inlinable
    public func borrowing(_ body: (borrowing Element) -> Void) {
        callAsFunction(body)
    }
}

// ============================================================================
// MARK: - Properties
// ============================================================================

extension Array.Fixed {
    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { count == .zero }
}

// ============================================================================
// MARK: - Typed Subscript (~Copyable)
// ============================================================================

extension Array.Fixed where Element: ~Copyable {
    /// Accesses the element at the given typed index (borrowing access for ~Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Index) -> Element {
        _read {
            precondition(index < count, "Index out of bounds")
            yield unsafe _cachedPtr[index]
        }
        _modify {
            precondition(index < count, "Index out of bounds")
            yield &(unsafe _cachedPtr[index])
        }
    }
}

// ============================================================================
// MARK: - Borrowed Element Access (for ~Copyable elements)
// ============================================================================

extension Array.Fixed where Element: ~Copyable {
    /// Accesses the element at the given index via closure (for ~Copyable elements).
    ///
    /// This method provides borrowed access to elements, enabling safe read access
    /// to move-only types without consuming them.
    ///
    /// - Parameters:
    ///   - index: The index of the element.
    ///   - body: A closure that receives a borrowed reference to the element.
    /// - Returns: The result of the closure.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return unsafe body(_cachedPtr[index])
    }
}

// ============================================================================
// MARK: - Buffer Access (Escape Hatch for C Interop)
// ============================================================================

@_spi(Unsafe)
extension Array.Fixed where Element: ~Copyable {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: This is an escape hatch for C interop. Prefer `span` for safe access.
    /// - Warning: The pointer must not escape the closure scope.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(UnsafeBufferPointer(start: count.rawValue > 0 ? _cachedPtr.base : nil, count: count.rawValue))
    }

    /// Provides mutable access to the underlying contiguous storage.
    ///
    /// - Warning: This is an escape hatch for C interop. Prefer `mutableSpan` for safe access.
    /// - Warning: The pointer must not escape the closure scope.
    @unsafe
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(UnsafeMutableBufferPointer(start: count.rawValue > 0 ? _cachedPtr.base : nil, count: count.rawValue))
    }
}

// ============================================================================
// MARK: - Span Access (Normative)
// ============================================================================

extension Array.Fixed where Element: ~Copyable {
    /// Read-only span of the array elements.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the borrow of `self`.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - The returned span is lifetime-dependent; the compiler is expected to diagnose escapes.
    /// - Violating this contract is undefined behavior.
    @inlinable
    public var span: Swift.Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            unsafe Swift.Span(_unsafeStart: _cachedPtr.base, count: count.rawValue)
        }
    }

    /// Mutable span of the array elements.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the exclusive mutable borrow.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - The returned span is lifetime-dependent; the compiler is expected to diagnose escapes.
    /// - No concurrent mutable borrows are permitted.
    /// - No mutable + immutable borrow overlap is permitted.
    /// - Violating this contract is undefined behavior.
    @inlinable
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            unsafe MutableSpan(_unsafeStart: _cachedPtr.base, count: count.rawValue)
        }
    }
}
