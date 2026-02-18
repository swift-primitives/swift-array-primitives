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

// MARK: - Default Implementations

extension __ArrayProtocol where Self: ~Copyable {
    /// Calls `body` with each valid index from `startIndex` to `endIndex`.
    @inlinable
    public func forEachIndex(_ body: (Index) -> Void) {
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
