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

import Property_Primitives

// MARK: - Default Implementations

extension Array.`Protocol` where Self: ~Copyable {
    /// Calls `body` with each valid index from `startIndex` to `endIndex`.
    @inlinable
    public func forEach(_ body: (Index) -> Void) {
        var i = startIndex
        while i < endIndex {
            body(i)
            i = index(after: i)
        }
    }

    /// Calls `body` with a borrowing reference to the element at `index`.
    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R {
        body(self[index])
    }
}

// MARK: ForEach: Borrowing Operations on .Typed (~Copyable)

extension Property.View.Typed
where Tag == Sequence.ForEach, Base: Array.`Protocol` & ~Copyable, Element: ~Copyable {
    /// Borrowing iteration: `.forEach { }`
    @inlinable
    public func callAsFunction(_ body: (borrowing Base.Element) -> Void) {
        var i = unsafe base.pointee.startIndex
        while unsafe i < base.pointee.endIndex {
            body(unsafe base.pointee[i])
            i = unsafe base.pointee.index(after: i)
        }
    }

    /// Explicit borrowing iteration: `.forEach.borrowing { }`
    @inlinable
    public func borrowing(_ body: (borrowing Base.Element) -> Void) {
        callAsFunction(body)
    }
}

