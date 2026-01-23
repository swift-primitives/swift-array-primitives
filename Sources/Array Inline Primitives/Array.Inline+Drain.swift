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

// MARK: - Drain View Type

extension Array.Inline where Element: ~Copyable {
    /// View type for drain operations.
    ///
    /// Provides `.drain { }` via `callAsFunction`, which removes all elements
    /// from the array and passes each to the closure with ownership.
    /// Works for ALL element types including `~Copyable`.
    @safe
    public struct DrainView: ~Copyable {
        @usableFromInline
        let _base: UnsafeMutablePointer<Array<Element>.Inline<capacity>>

        @usableFromInline
        init(_ base: UnsafeMutablePointer<Array<Element>.Inline<capacity>>) {
            unsafe _base = base
        }
    }
}

// MARK: - Drain Property

extension Array.Inline where Element: ~Copyable {
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
    public var drain: DrainView {
        mutating _read {
            yield unsafe DrainView(&self)
        }
        mutating _modify {
            var view = unsafe DrainView(&self)
            yield &view
        }
    }
}

// MARK: - DrainView: Drain Operations (~Copyable)

extension Array.Inline.DrainView where Element: ~Copyable {
    /// Drain iteration: `.drain { }`
    ///
    /// Removes all elements from the array, passing each to the closure
    /// with ownership. After this call, the array is empty but usable.
    /// Works for ALL element types including `~Copyable`.
    ///
    /// - Parameter body: A closure called with each element (consuming).
    @inlinable
    public mutating func callAsFunction(_ body: (consuming Element) -> Void) {
        let count = unsafe _base.pointee._count.rawValue
        guard count > 0 else { return }
        for i in 0..<count {
            body(unsafe _base.pointee._storage.move(at: i))
        }
        unsafe _base.pointee._count = Index<Element>.Count(__unchecked: 0)
    }
}
