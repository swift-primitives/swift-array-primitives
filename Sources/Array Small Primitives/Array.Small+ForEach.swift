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

extension Array.Small where Element: ~Copyable {
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
    /// var array = try Array<Int>.Small<4>()
    /// array.append(1)
    /// array.append(2)
    /// array.append(3)
    ///
    /// // Borrowing iteration (works for ALL elements)
    /// array.forEach { print($0) }
    ///
    /// // Consuming iteration (Copyable elements only)
    /// array.forEach.consuming { print($0) }
    /// // array is now empty
    /// ```
    @inlinable
    public var forEach: Property<Sequence.ForEach, Self>.View.Typed<Element>.Valued<inlineCapacity> {
        mutating _read {
            yield unsafe Property<Sequence.ForEach, Self>.View.Typed<Element>.Valued<inlineCapacity>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.ForEach, Self>.View.Typed<Element>.Valued<inlineCapacity>(&self)
            yield &view
        }
    }
}

// MARK: - ForEach: Borrowing Operations (~Copyable)

extension Property.View.Typed.Valued
where Tag == Sequence.ForEach, Base == Array<Element>.Small<n>, Element: ~Copyable {
    /// Borrowing iteration: `.forEach { }`
    ///
    /// Iterates over all elements without consuming them.
    /// Works for ALL element types including `~Copyable`.
    ///
    /// - Parameter body: A closure called with each borrowed element.
    @inlinable
    public func callAsFunction(_ body: (borrowing Element) -> Void) {
        let count = unsafe base.pointee.count.rawValue
        guard count > 0 else { return }

        if let heapState = unsafe base.pointee.heap {
            _ = unsafe heapState.storage.withUnsafeMutablePointerToElements { elements in
                for i in 0..<count {
                    unsafe body((elements + i).pointee)
                }
            }
        } else {
            let stride = MemoryLayout<Element>.stride
            unsafe withUnsafePointer(to: base.pointee.inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                for i in 0..<count {
                    let elementPtr = unsafe (basePtr + i * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe body(elementPtr.pointee)
                }
            }
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

// MARK: - ForEach: Consuming Operations (Copyable only)

extension Property.View.Typed.Valued
where Tag == Sequence.ForEach, Base == Array<Element>.Small<n>, Element: Copyable {
    /// Consuming iteration: `.forEach.consuming { }`
    ///
    /// Iterates over all elements and then clears the array.
    /// Only available for `Copyable` elements.
    ///
    /// - Parameter body: A closure called with each element.
    @_lifetime(&self)
    @inlinable
    public mutating func consuming(_ body: (Element) -> Void) {
        let count = unsafe base.pointee.count
        guard count > 0 else { return }

        if let heapState = unsafe base.pointee.heap {
            _ = unsafe heapState.storage.withUnsafeMutablePointerToElements { elements in
                for i in 0..<count {
                    unsafe body((elements + i).pointee)
                }
            }
            heapState.storage.deinitialize()
        } else {
            let stride = MemoryLayout<Element>.stride
            unsafe withUnsafePointer(to: base.pointee.inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                for i in 0..<count {
                    let elementPtr = unsafe (basePtr + i * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe body(elementPtr.pointee)
                }
            }
            unsafe base.pointee.inline.deinitialize(count: count)
        }
        unsafe base.pointee.count = .zero
    }
}
