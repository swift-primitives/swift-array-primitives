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
// MARK: - Collection Conformances
// ============================================================================

// MARK: Collection.Indexed

extension Array.Static: Collection.Indexed where Element: ~Copyable {
    public typealias Index = Array<Element>.Index

    @inlinable
    public var startIndex: Index { .zero }

    @inlinable
    public var endIndex: Index { Index(count) }

    @inlinable
    public func index(after i: Index) -> Index { (i + 1)! }
}

// MARK: Collection.Bidirectional

extension Array.Static: Collection.Bidirectional where Element: ~Copyable {
    @inlinable
    public func index(before i: Index) -> Index { (i - 1)! }
}

// ============================================================================
// MARK: - Properties
// ============================================================================

extension Array.Static where Element: ~Copyable {
    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { count == .zero }

    /// Whether the array is at full capacity.
    @inlinable
    public var isFull: Bool { count.rawValue >= capacity }
}

// ============================================================================
// MARK: - Subscripts
// ============================================================================

// MARK: Index Subscript

extension Array.Static where Element: ~Copyable {
    /// Accesses the element at the given typed index (borrowing access for ~Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Index) -> Element {
        _read {
            precondition(index < count, "Index out of bounds")
            yield unsafe storage.read(at: index).pointee
        }
        _modify {
            precondition(index < count, "Index out of bounds")
            yield &(unsafe storage.pointer(at: index).pointee)
        }
    }
}

// MARK: Bounded Subscript

extension Array.Static where Element: ~Copyable {
    /// Accesses the element at the given bounded index.
    ///
    /// The type `Index<Element>.Bounded<capacity>` proves `0 <= index < capacity`.
    /// **No runtime bounds check is performed.**
    ///
    /// ## Type-Based Safety
    ///
    /// The TYPE encodes the bounds proof:
    /// - `Index<Element>` subscript → has runtime bounds check
    /// - `Index<Element>.Bounded<capacity>` subscript → NO bounds check (type proves it)
    ///
    /// ## Contract
    ///
    /// For full arrays (`count == capacity`), this subscript is completely safe.
    /// For partial arrays (`count < capacity`), caller must ensure `index < count`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var inline = Array<Int>.Inline<8>()
    /// // Fill to capacity...
    /// assert(inline.isFull)
    ///
    /// let idx: Index<Int>.Bounded<8> = 3
    /// print(inline[idx])  // No runtime bounds check - type proves 0 <= 3 < 8
    /// ```
    ///
    /// - Parameter index: A bounded index where the type proves `0 <= index < capacity`.
    @inlinable
    public subscript(_ index: Index.Bounded<capacity>) -> Element {
        _read {
            // Type proves: 0 <= index < capacity
            // For full arrays: count == capacity, so 0 <= index < count ✓
            yield unsafe storage.read(at: index.unbounded).pointee
        }
        _modify {
            yield &(unsafe storage.pointer(at: index.unbounded).pointee)
        }
    }
}

// ============================================================================
// MARK: - Element Access
// ============================================================================

extension Array.Static where Element: ~Copyable {
    /// Accesses the element at the given index via closure (for ~Copyable elements).
    ///
    /// - Parameters:
    ///   - index: The index of the element.
    ///   - body: A closure that receives a borrowed reference to the element.
    /// - Returns: The result of the closure.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return unsafe body(storage.read(at: index).pointee)
    }
}

// ============================================================================
// MARK: - Mutating Operations
// ============================================================================

extension Array.Static where Element: ~Copyable {
    /// Appends an element to the array.
    ///
    /// - Parameter element: The element to append (consumed).
    /// - Throws: ``Array.Static.Error.overflow`` if the array is full.
    @inlinable
    public mutating func append(_ element: consuming Element) throws(Array.Static.Error) {
        guard count.rawValue < capacity else {
            throw .overflow
        }
        storage.initialize(to: element, at: .init(count))
        count = Index.Count(__unchecked: count.rawValue + 1)
    }

    /// Removes and returns the last element.
    ///
    /// - Returns: The removed element, or `nil` if the array is empty.
    @inlinable
    public mutating func removeLast() -> Element? {
        guard let new: Index.Count = count - 1 else { return nil }
        self.count = new
        return storage.move(at: .init(new))
    }

    /// Removes all elements from the array.
    @inlinable
    public mutating func removeAll() {
        guard count.rawValue > 0 else { return }
        storage.deinitialize(count: count)
        count = .zero
    }
}

// ============================================================================
// MARK: - Span Access
// ============================================================================

extension Array.Static where Element: ~Copyable {
    /// Provides read-only span access to the array elements.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the closure.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - Violating this contract is undefined behavior.
    ///
    /// ## Note
    ///
    /// Inline storage requires closure-based access because the storage address
    /// is not stable (it moves with the struct). Use `span` property on heap-backed
    /// variants (Fixed, Array) for direct access.
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        _ body: (Swift.Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        return try unsafe withUnsafePointer(to: storage.raw) { storagePtr throws(E) -> R in
            let basePtr = unsafe UnsafeRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            let span = unsafe Swift.Span(_unsafeStart: elementPtr, count: count.rawValue)
            return try body(span)
        }
    }

    /// Provides mutable span access to the array elements.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the closure.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - No concurrent mutable borrows are permitted.
    /// - Violating this contract is undefined behavior.
    ///
    /// ## Note
    ///
    /// Inline storage requires closure-based access because the storage address
    /// is not stable (it moves with the struct). Use `mutableSpan` property on
    /// heap-backed variants (Fixed, Array) for direct access.
    @inlinable
    public mutating func withMutableSpan<R, E: Swift.Error>(
        _ body: (borrowing MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        return try unsafe withUnsafeMutablePointer(to: &storage.raw) { storagePtr throws(E) -> R in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            let span = unsafe MutableSpan(_unsafeStart: elementPtr, count: count.rawValue)
            return try body(span)
        }
    }
}

// ============================================================================
// MARK: - Buffer Access
// ============================================================================

@_spi(Unsafe)
extension Array.Static where Element: ~Copyable {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: This is an escape hatch for C interop. Prefer `span` for safe access.
    /// - Warning: The pointer must not escape the closure scope.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        return try unsafe withUnsafePointer(to: storage.raw) { storagePtr throws(E) -> R in
            let basePtr = unsafe UnsafeRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            return try unsafe body(UnsafeBufferPointer(start: count.rawValue > 0 ? elementPtr : nil, count: count.rawValue))
        }
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
        return try unsafe withUnsafeMutablePointer(to: &storage.raw) { storagePtr throws(E) -> R in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            return try unsafe body(UnsafeMutableBufferPointer(start: count.rawValue > 0 ? elementPtr : nil, count: count.rawValue))
        }
    }
}

// ============================================================================
// MARK: - Property Views
// ============================================================================

// MARK: ForEach Property View

extension Array.Static where Element: ~Copyable {
    /// Property view for iteration operations.
    ///
    /// Provides iteration patterns for ALL element types including `~Copyable`:
    /// - `.forEach { }` — Borrowing iteration via `callAsFunction`
    /// - `.forEach.borrowing { }` — Explicit borrowing iteration
    ///
    /// For `Copyable` elements only:
    /// - `.forEach.consuming { }` — Consuming iteration (clears array)
    ///
    /// ## Example
    ///
    /// ```swift
    /// var array = Array<Int>.Inline<8>()
    /// try array.append(1)
    /// try array.append(2)
    /// try array.append(3)
    ///
    /// // Borrowing iteration (works for ALL elements)
    /// array.forEach { print($0) }
    ///
    /// // Consuming iteration (Copyable elements only)
    /// array.forEach.consuming { print($0) }
    /// // array is now empty
    /// ```
    ///
    /// ## ~Copyable Elements
    ///
    /// For `~Copyable` elements, `.forEach { }` provides borrowing access:
    ///
    /// ```swift
    /// struct Handle: ~Copyable { var id: Int }
    ///
    /// var handles = Array<Handle>.Inline<4>()
    /// try handles.append(Handle(id: 1))
    /// try handles.append(Handle(id: 2))
    ///
    /// handles.forEach { print($0.id) }  // Borrows each handle
    /// // handles still contains both handles
    /// ```
    @inlinable
    public var forEach: Property<Sequence.ForEach, Self>.View.Typed<Element>.Valued<capacity> {
        mutating _read {
            yield unsafe Property<Sequence.ForEach, Self>.View.Typed<Element>.Valued<capacity>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.ForEach, Self>.View.Typed<Element>.Valued<capacity>(&self)
            yield &view
        }
    }
}

// MARK: ForEach: Borrowing Operations (~Copyable)

extension Property.View.Typed.Valued
where Tag == Sequence.ForEach, Base == Array<Element>.Static<n>, Element: ~Copyable {
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
            unsafe body(base.pointee.storage.read(at: i).pointee)
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
        let count = unsafe base.pointee.count
        (0..<count).forEach { i in
            unsafe body(base.pointee.storage.read(at: i).pointee)
        }
    }
}

// MARK: Drain Property View

extension Array.Static where Element: ~Copyable {
    /// Property view for draining operations.
    ///
    /// Provides `.drain { }` via `callAsFunction`, which removes all elements
    /// from the array and passes each to the closure with ownership.
    /// Works for ALL element types including `~Copyable`.
    ///
    /// After draining, the array is empty but still usable.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var array = Array<Int>.Inline<8>()
    /// try array.append(1)
    /// try array.append(2)
    /// try array.append(3)
    ///
    /// // Drain all elements (takes ownership)
    /// array.drain { element in
    ///     process(element)
    /// }
    /// // array is now empty but still usable
    /// try array.append(4)
    /// ```
    ///
    /// ## ~Copyable Elements
    ///
    /// For `~Copyable` elements, `.drain { }` transfers ownership:
    ///
    /// ```swift
    /// struct Handle: ~Copyable {
    ///     var id: Int
    ///     consuming func close() { print("Closing \(id)") }
    /// }
    ///
    /// var handles = Array<Handle>.Inline<4>()
    /// try handles.append(Handle(id: 1))
    /// try handles.append(Handle(id: 2))
    ///
    /// handles.drain { handle in
    ///     handle.close()  // Takes ownership, can consume
    /// }
    /// // handles is now empty
    /// ```
    @inlinable
    public var drain: Property<Sequence.Drain, Self>.View.Typed<Element>.Valued<capacity> {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View.Typed<Element>.Valued<capacity>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View.Typed<Element>.Valued<capacity>(&self)
            yield &view
        }
    }
}

// MARK: Drain: Operations (~Copyable)

extension Property.View.Typed.Valued
where Tag == Sequence.Drain, Base == Array<Element>.Static<n>, Element: ~Copyable {
    /// Drain iteration: `.drain { }`
    ///
    /// Removes all elements from the array, passing each to the closure
    /// with ownership. After this call, the array is empty but usable.
    /// Works for ALL element types including `~Copyable`.
    ///
    /// - Parameter body: A closure called with each element (consuming).
    @_lifetime(&self)
    @inlinable
    public mutating func callAsFunction(_ body: (consuming Element) -> Void) {
        let count = unsafe base.pointee.count
        guard count > .zero else { return }
        (0..<count).forEach { i in
            body(unsafe base.pointee.storage.move(at: i))
        }
        unsafe base.pointee.count = .zero
    }
}
