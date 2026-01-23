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
public import Index_Primitives

// MARK: - ForEach View Type

extension Array.Inline where Element: ~Copyable {
    /// View type for forEach iteration operations.
    ///
    /// Provides iteration patterns for ALL element types including `~Copyable`:
    /// - `.forEach { }` — Borrowing iteration via `callAsFunction`
    /// - `.forEach.borrowing { }` — Explicit borrowing iteration
    ///
    /// For `Copyable` elements only:
    /// - `.forEach.consuming { }` — Consuming iteration (clears array)
    @safe
    public struct ForEachView: ~Copyable {
        @usableFromInline
        let _base: UnsafeMutablePointer<Array<Element>.Inline<capacity>>

        @usableFromInline
        init(_ base: UnsafeMutablePointer<Array<Element>.Inline<capacity>>) {
            unsafe _base = base
        }
    }
}

// MARK: - ForEach Property

extension Array.Inline where Element: ~Copyable {
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
    public var forEach: ForEachView {
        mutating _read {
            yield unsafe ForEachView(&self)
        }
        mutating _modify {
            var view = unsafe ForEachView(&self)
            yield &view
        }
    }
}

// MARK: - ForEachView: Borrowing Operations (~Copyable)

extension Array.Inline.ForEachView where Element: ~Copyable {
    /// Borrowing iteration: `.forEach { }`
    ///
    /// Iterates over all elements without consuming them.
    /// Works for ALL element types including `~Copyable`.
    ///
    /// - Parameter body: A closure called with each borrowed element.
    @inlinable
    public func callAsFunction(_ body: (borrowing Element) -> Void) {
        let count = unsafe _base.pointee._count.rawValue
        for i in 0..<count {
            unsafe body(_base.pointee._storage.read(at: i).pointee)
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
        let count = unsafe _base.pointee._count.rawValue
        for i in 0..<count {
            unsafe body(_base.pointee._storage.read(at: i).pointee)
        }
    }
}

// MARK: - ForEachView: Consuming Operations (Copyable only)

extension Array.Inline.ForEachView where Element: Copyable {
    /// Consuming iteration: `.forEach.consuming { }`
    ///
    /// Iterates over all elements and then clears the array.
    /// Only available for `Copyable` elements.
    ///
    /// - Parameter body: A closure called with each element.
    @inlinable
    public mutating func consuming(_ body: (Element) -> Void) {
        let count = unsafe _base.pointee._count.rawValue
        for i in 0..<count {
            unsafe body(_base.pointee._storage.read(at: i).pointee)
        }
        unsafe _base.pointee._storage.deinitialize(count: count)
        unsafe _base.pointee._count = Index<Element>.Count(__unchecked: 0)
    }
}
