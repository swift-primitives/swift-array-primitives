//
//  File.swift
//  swift-array-primitives
//
//  Created by Coen ten Thije Boonkkamp on 24/01/2026.
//

public import Array_Primitives_Core

extension Array {
    public typealias Dynamic = Array_Primitives_Core.Array<Element>
}

extension Array: Swift.Sequence where Element: Copyable {
    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { count.rawValue }
}

// MARK: - Swift.Collection Conformance
// Bridge to Swift standard library collections for interop with stdlib algorithms.
// Requirements satisfied by Collection.Protocol conformance above.

extension Array: Swift.Collection where Element: Copyable {}
extension Array: Swift.BidirectionalCollection where Element: Copyable {}
extension Array: Swift.RandomAccessCollection where Element: Copyable {}
