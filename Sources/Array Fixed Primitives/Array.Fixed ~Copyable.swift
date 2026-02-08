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

extension Array.Fixed: Collection.`Protocol` {}

// MARK: - Collection.Access.Random Conformance

extension Array.Fixed: Collection.Access.Random {}

// MARK: - Collection.Indexed Conformance

extension Array.Fixed: Collection.Indexed where Element: ~Copyable {
    public typealias Index = Array<Element>.Index

    @inlinable
    public var startIndex: Index { .zero }

    @inlinable
    public var endIndex: Index { Index(count) }

    @inlinable
    public func index(after i: Index) -> Index { i + Index.Count.one }
}

// MARK: - Collection.Bidirectional Conformance

extension Array.Fixed: Collection.Bidirectional where Element: ~Copyable {
    @inlinable
    public func index(before i: Index) -> Index { try! (i - Index.Offset.one) }
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
        let base: UnsafePointer<Element>

        @usableFromInline
        let end: Index.Count

        @usableFromInline
        var index: Index

        @usableFromInline @unsafe
        init(base: UnsafePointer<Element>, count: Index.Count) {
            unsafe self.base = base
            self.end = count
            self.index = .zero
        }

        @inlinable
        public mutating func next() -> Element? {
            guard index < end else { return nil }
            let result = unsafe base[Int(bitPattern: index)]
            index = index + Index.Count.one
            return result
        }
    }
}

extension Array.Fixed.Iterator: @unchecked Sendable where Element: Sendable {}

// MARK: - Sequence.Protocol Conformance

extension Array.Fixed: Sequence.`Protocol` {
    /// Returns a pointer-based iterator over the array elements.
    @inlinable
    public borrowing func makeIterator() -> Array.Fixed.Iterator {
        let count = _buffer.count
        guard count > .zero else {
            return unsafe Iterator(base: UnsafePointer<Element>(bitPattern: 1)!, count: .zero)
        }
        let span = _buffer.span
        return unsafe Iterator(base: span.unsafeBaseAddress!, count: count)
    }
}

// ============================================================================
// MARK: - ForEach Property View
// ============================================================================

extension Array.Fixed where Element: ~Copyable {
    /// Property view for iteration operations.
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
    @inlinable
    public func callAsFunction(_ body: (borrowing Element) -> Void) {
        let count = unsafe base.pointee._buffer.count
        guard count > .zero else { return }
        for i in 0..<Int(bitPattern: count) {
            let slot = Index_Primitives.Index<Element>(Ordinal(UInt(i)))
            body(unsafe base.pointee._buffer[slot])
        }
    }

    /// Explicit borrowing iteration: `.forEach.borrowing { }`
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
            yield _buffer[index]
        }
        _modify {
            precondition(index < count, "Index out of bounds")
            yield &_buffer[index]
        }
    }
}

// ============================================================================
// MARK: - Borrowed Element Access (for ~Copyable elements)
// ============================================================================

extension Array.Fixed where Element: ~Copyable {
    /// Accesses the element at the given index via closure (for ~Copyable elements).
    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return body(_buffer[index])
    }
}

// ============================================================================
// MARK: - Buffer Access (Escape Hatch for C Interop)
// ============================================================================

@_spi(Unsafe)
extension Array.Fixed where Element: ~Copyable {
    /// Provides read-only access to the underlying contiguous storage.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        try _buffer.withUnsafeBufferPointer(body)
    }

    /// Provides mutable access to the underlying contiguous storage.
    @unsafe
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let count = Int(bitPattern: _buffer.count)
        let ptr = count > 0 ? unsafe UnsafeMutablePointer(mutating: _buffer.span.unsafeBaseAddress!) : nil
        return try unsafe body(UnsafeMutableBufferPointer(start: ptr, count: count))
    }
}

// ============================================================================
// MARK: - Span Access (Normative)
// ============================================================================

extension Array.Fixed where Element: ~Copyable {
    /// Read-only span of the array elements.
    @inlinable
    public var span: Swift.Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            _buffer.span
        }
    }

    /// Mutable span of the array elements.
    @inlinable
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            _buffer.mutableSpan
        }
    }
}
