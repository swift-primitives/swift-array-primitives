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

// MARK: - Drain Property

extension Array where Element: ~Copyable {
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
    /// var array = Array<Int>.Unbounded()
    /// array.append(1)
    /// array.append(2)
    /// array.append(3)
    ///
    /// // Drain all elements (takes ownership)
    /// array.drain { element in
    ///     process(element)
    /// }
    /// // array is now empty but still usable
    /// array.append(4)
    /// ```
    @inlinable
    public var drain: Property<Sequence.Drain, Self>.View.Typed<Element> {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View.Typed<Element>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View.Typed<Element>(&self)
            yield &view
        }
    }
}

// MARK: - Drain: Operations (~Copyable)

extension Property.View.Typed.Valued
where Tag == Sequence.Drain, Base == Array<Element>, Element: ~Copyable {
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
        let count = base.pointee._storage.header
        guard count > 0 else { return }
        _ = base.pointee._storage.withUnsafeMutablePointerToElements { elements in
            for i in 0..<count {
                body((elements + i).move())
            }
        }
        base.pointee._storage.header = 0
    }
}
