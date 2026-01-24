import Index_Primitives

// MARK: - Swift.Sequence Conformance
//
// Bridge to Swift.Sequence for `for-in` loops and stdlib algorithms.
// Requires explicit underestimatedCount to resolve ambiguity with
// Sequence.Protocol+Swift.Sequence default implementation.

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
