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
public import Collection_Primitives
public import Index_Primitives
public import Property_Primitives
public import Sequence_Primitives

// ============================================================================
// MARK: - Subscripts
// ============================================================================

extension Array.Small where Element: Copyable {
    /// Accesses the element at the given typed index (copy semantics for Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Index) -> Element {
        get {
            precondition(index < count, "Index out of bounds")
            if let heap {
                return unsafe heap.pointer[index]
            } else {
                // Use withUnsafePointer directly - inline accessor requires mutating context
                let stride = Affine.Discrete.Ratio<Element, UInt8>(MemoryLayout<Element>.stride)
                return unsafe withUnsafePointer(to: inline) { storagePtr in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let elementPtr = unsafe (basePtr + (Index<Element>.Offset(index) * stride).vector.rawValue)
                        .assumingMemoryBound(to: Element.self)
                    return unsafe elementPtr.pointee
                }
            }
        }
        set {
            precondition(index < count, "Index out of bounds")
            if heap != nil {
                _ = heap!.storage.move(at: index)
                heap!.storage.initialize(to: newValue, at: index)
            } else {
                unsafe inline.pointer(at: index).pointee = newValue
            }
        }
    }
}

// ============================================================================
// MARK: - Element Access
// ============================================================================

extension Array.Small where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Index) -> Element? {
        guard index < count else { return nil }
        if let heap {
            return unsafe heap.pointer[index]
        } else {
            // Use withUnsafePointer directly - inline accessor requires mutating context
            let stride = Affine.Discrete.Ratio<Element, UInt8>(MemoryLayout<Element>.stride)
            return unsafe withUnsafePointer(to: inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + (Index<Element>.Offset(index) * stride).vector.rawValue)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr.pointee
            }
        }
    }

    /// Returns element at index offset from given base index.
    ///
    /// - Parameters:
    ///   - base: The starting index.
    ///   - offset: The signed offset from the base.
    /// - Returns: The element at the computed position, or `nil` if out of bounds.
    @inlinable
    public func element(
        at base: Index,
        offsetBy offset: Index.Offset
    ) -> Element? {
        guard let newIndex = base + offset else { return nil }
        guard newIndex < count else { return nil }
        if let heap {
            return unsafe heap.pointer[newIndex]
        } else {
            // Use withUnsafePointer directly - inline accessor requires mutating context
            let stride = Affine.Discrete.Ratio<Element, UInt8>(MemoryLayout<Element>.stride)
            return unsafe withUnsafePointer(to: inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + (Index<Element>.Offset(newIndex) * stride).vector.rawValue)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr.pointee
            }
        }
    }
}

// ============================================================================
// MARK: - Property View Operations
// ============================================================================

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
        guard count > .zero else { return }

        if let heapState = unsafe base.pointee.heap {
            _ = unsafe heapState.storage.withUnsafeMutablePointerToElements { elements in
                for i in 0..<count.rawValue {
                    unsafe body(elements[i])
                }
            }
            heapState.storage.deinitialize()
        } else {
            // Inline storage uses stride-based raw pointer arithmetic
            let stride = MemoryLayout<Element>.stride
            unsafe withUnsafePointer(to: base.pointee.inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                for i in 0..<count.rawValue {
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
