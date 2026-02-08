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
                return unsafe heap.pointer[Int(bitPattern: index)]
            } else {
                return _inlineBuffer[index]
            }
        }
        set {
            precondition(index < count, "Index out of bounds")
            if heap != nil {
                _ = heap!.storage.move(at: index)
                heap!.storage.initialize(to: newValue, at: index)
            } else {
                _inlineBuffer[index] = newValue
            }
        }
    }
}

// ============================================================================
// MARK: - Element Access
// ============================================================================

extension Array.Small where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    @inlinable
    public func element(at index: Index) -> Element? {
        guard index < count else { return nil }
        if let heap {
            return unsafe heap.pointer[Int(bitPattern: index)]
        } else {
            return _inlineBuffer[index]
        }
    }

    /// Returns element at index offset from given base index.
    @inlinable
    public func element(
        at base: Index,
        offsetBy offset: Index.Offset
    ) -> Element? {
        guard let newIndex = try? (base + offset) else { return nil }
        guard newIndex < count else { return nil }
        if let heap {
            return unsafe heap.pointer[Int(bitPattern: newIndex)]
        } else {
            return _inlineBuffer[newIndex]
        }
    }
}

// ============================================================================
// MARK: - Property View Operations
// ============================================================================

extension Property.View.Typed.Valued
where Tag == Sequence.ForEach, Base == Array<Element>.Small<n>, Element: Copyable {
    /// Consuming iteration: `.forEach.consuming { }`
    @_lifetime(&self)
    @inlinable
    public mutating func consuming(_ body: (Element) -> Void) {
        let count = unsafe base.pointee.count
        guard count > .zero else { return }

        if let heapState = unsafe base.pointee.heap {
            _ = unsafe heapState.storage.withUnsafeMutablePointerToElements { elements in
                for i in 0..<Int(bitPattern: count) {
                    unsafe body(elements[i])
                }
            }
            heapState.storage.deinitialize()
        } else {
            for i in 0..<Int(bitPattern: count) {
                let slot = Index_Primitives.Index<Element>(Ordinal(UInt(i)))
                body(unsafe base.pointee._inlineBuffer[slot])
            }
            unsafe base.pointee._inlineBuffer.removeAll()
        }
        unsafe base.pointee.count = .zero
    }
}
