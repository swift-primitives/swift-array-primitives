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
public import Property_Primitives
public import Sequence_Primitives

// MARK: - ForEach Property

extension Array.Fixed where Element: ~Copyable {
    /// Property view for iteration operations.
    ///
    /// Provides iteration patterns for ALL element types including `~Copyable`:
    /// - `.forEach { }` — Borrowing iteration via `callAsFunction`
    /// - `.forEach.borrowing { }` — Explicit borrowing iteration
    ///
    /// ## Note
    ///
    /// `Array.Bounded` has a fixed count (immutable), so `.forEach.consuming { }` and
    /// `.drain { }` are not available. Use `Array.Unbounded` or `Array.Small` for
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
        let count = base.pointee._count.rawValue
        for i in 0..<count {
            unsafe body((base.pointee._cachedPtr + i).pointee)
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

// Note: Array.Bounded has immutable count (_count is `let`), so consuming/drain
// operations are not supported. Use Array.Unbounded or Array.Small instead.
