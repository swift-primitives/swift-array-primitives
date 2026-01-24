//
//  File.swift
//  swift-array-primitives
//
//  Created by Coen ten Thije Boonkkamp on 24/01/2026.
//

public import Array_Primitives_Core
public import Index_Primitives

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
            let stride = MemoryLayout<Element>.stride
            return unsafe withUnsafePointer(to: inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + index.position.rawValue * stride)
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
            let stride = MemoryLayout<Element>.stride
            return unsafe withUnsafePointer(to: inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + newIndex.position.rawValue * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr.pointee
            }
        }
    }
}

// MARK: - Typed Subscript

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
                let stride = MemoryLayout<Element>.stride
                return unsafe withUnsafePointer(to: inline) { storagePtr in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let elementPtr = unsafe (basePtr + index.position.rawValue * stride)
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
