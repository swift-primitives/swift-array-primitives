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
public import Range_Primitives
public import Sequence_Primitives

// MARK: - Drain Property

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

// MARK: - Drain: Operations (~Copyable)

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
        (0..<count).drain { i in
            body(unsafe base.pointee.storage.move(at: i))
        }
        unsafe base.pointee.count = .zero
    }
}
