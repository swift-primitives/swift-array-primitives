//
//  File.swift
//  swift-array-primitives
//
//  Created by Coen ten Thije Boonkkamp on 23/01/2026.
//

public import Array_Primitives_Core
public import Sequence_Primitives
public import Index_Primitives

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
