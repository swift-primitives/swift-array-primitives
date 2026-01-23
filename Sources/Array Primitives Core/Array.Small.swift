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

// Note: Array.Small is declared INSIDE the Array enum body (in Array.swift)
// due to a Swift compiler bug where nested types with value generic parameters
// declared in extensions do not properly inherit ~Copyable constraints from
// the outer type. This file contains only the minimal extensions required
// for the workaround. Public API is in Array Small Primitives module.

public import Index_Primitives

extension Array where Element: ~Copyable {

    // MARK: - Small (SmallVec Pattern)

    /// An array with small-buffer optimization (SmallVec pattern).
    ///
    /// `Array.Small` stores up to `inlineCapacity` elements in inline storage,
    /// then automatically spills to heap storage when that capacity is exceeded.
    ///
    /// - Note: This type is declared inside `Array` (not in an extension) due to a
    ///   Swift compiler bug. Public API is in the Array Small Primitives module.
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        /// Maximum element stride supported by inline storage (64 bytes per slot).
        @usableFromInline
        package static var _maxElementStride: Int { 64 }

        /// Raw byte storage for inline elements.
        @usableFromInline
        package var _inlineElements: InlineArray<inlineCapacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        /// Current element count (valid in both inline and heap modes).
        @usableFromInline
        package var _count: Index_Primitives.Index<Element>.Count

        /// Heap storage for elements when spilled. Nil when using inline storage.
        @usableFromInline
        package var _heapStorage: Unbounded<inlineCapacity>.ElementStorage?

        /// Cached pointer to heap elements. Only valid when _heapStorage is non-nil.
        @usableFromInline
        package var _heapPtr: UnsafeMutablePointer<Element>?

        /// Creates an empty small array.
        @inlinable
        public init() {
            precondition(
                MemoryLayout<Element>.stride <= Self._maxElementStride,
                "Element stride (\(MemoryLayout<Element>.stride)) exceeds inline storage slot size (\(Self._maxElementStride) bytes). Use Array.Unbounded instead."
            )
            precondition(
                MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment,
                "Element alignment (\(MemoryLayout<Element>.alignment)) exceeds inline storage alignment (\(MemoryLayout<Int>.alignment)). Use Array.Unbounded instead."
            )
            self._inlineElements = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
            self._count = .zero
            self._heapStorage = nil
            unsafe (self._heapPtr = nil)
        }

        deinit {
            let count = _count.rawValue
            guard count > 0 else { return }

            if let heap = _heapStorage {
                // Elements are on heap - ElementStorage handles cleanup via its deinit
                heap.header = count
            } else {
                // Elements are inline - clean up manually
                let stride = MemoryLayout<Element>.stride
                unsafe Swift.withUnsafeBytes(of: _inlineElements) { bytes in
                    let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                    for i in 0..<count {
                        let elementPtr = unsafe (basePtr + i * stride)
                            .assumingMemoryBound(to: Element.self)
                        unsafe elementPtr.deinitialize(count: 1)
                    }
                }
            }
        }
    }
}

extension Array.Small: @unchecked Sendable where Element: Sendable {}

// MARK: - Internal Helpers (package access for cross-module use)

extension Array.Small where Element: ~Copyable {
    /// Returns a mutable pointer to the inline element at the given index.
    @usableFromInline
    @unsafe
    package mutating func _inlinePointerToElement(at index: Int) -> UnsafeMutablePointer<Element> {
        let stride = MemoryLayout<Element>.stride
        return unsafe Swift.withUnsafeMutablePointer(to: &_inlineElements) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            let elementPtr = unsafe (basePtr + index * stride)
                .assumingMemoryBound(to: Element.self)
            return unsafe elementPtr
        }
    }

    /// Returns a read-only pointer to the inline element at the given index.
    @usableFromInline
    @unsafe
    package func _inlineReadPointerToElement(at index: Int) -> UnsafePointer<Element> {
        let stride = MemoryLayout<Element>.stride
        return unsafe Swift.withUnsafePointer(to: _inlineElements) { storagePtr in
            let basePtr = unsafe UnsafeRawPointer(storagePtr)
            let elementPtr = unsafe (basePtr + index * stride)
                .assumingMemoryBound(to: Element.self)
            return unsafe elementPtr
        }
    }

    /// Spills inline storage to heap.
    @usableFromInline
    package mutating func _spillToHeap(minimumCapacity: Int) {
        precondition(_heapStorage == nil, "Already spilled")

        // Create heap storage with growth factor
        let newCapacity = Swift.max(minimumCapacity, inlineCapacity * 2, 8)
        let newStorage = Array<Element>.Unbounded<inlineCapacity>.ElementStorage.create(minimumCapacity: newCapacity)

        // Move elements from inline to heap
        let stride = MemoryLayout<Element>.stride
        _ = unsafe Swift.withUnsafeBytes(of: _inlineElements) { bytes in
            unsafe newStorage.withUnsafeMutablePointerToElements { heapPtr in
                let inlineBase = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                for i in 0..<_count.rawValue {
                    let inlineElement = unsafe (inlineBase + i * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe (heapPtr + i).initialize(to: inlineElement.move())
                }
            }
        }
        newStorage.header = _count.rawValue

        _heapStorage = newStorage
        unsafe (_heapPtr = newStorage._elementsPointer)
    }

    /// Ensures the heap has capacity for at least the specified number of elements.
    @usableFromInline
    package mutating func _ensureHeapCapacity(_ minimumCapacity: Int) {
        guard let heapStorage = _heapStorage else {
            preconditionFailure("Not in heap mode")
        }
        guard heapStorage.capacity < minimumCapacity else { return }

        let newCapacity = Swift.max(minimumCapacity, heapStorage.capacity * 2, 8)
        let newStorage = Array<Element>.Unbounded<inlineCapacity>.ElementStorage.create(minimumCapacity: newCapacity)
        let currentCount = heapStorage.header

        heapStorage._moveAllElements(to: newStorage)
        newStorage.header = currentCount
        _heapStorage = newStorage
        unsafe (_heapPtr = newStorage._elementsPointer)
    }
}

extension Array.Small where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Array<Element>.Index) -> Element? {
        guard index < _count else { return nil }
        if let heapPtr = unsafe _heapPtr {
            return unsafe heapPtr[index.position.rawValue]
        } else {
            return unsafe _inlineReadPointerToElement(at: index.position.rawValue).pointee
        }
    }
}

extension Array.Small where Element: Copyable {
    /// Returns element at index offset from given base index.
    ///
    /// - Parameters:
    ///   - base: The starting index.
    ///   - offset: The signed offset from the base.
    /// - Returns: The element at the computed position, or `nil` if out of bounds.
    @inlinable
    public func element(at base: Array<Element>.Index, offsetBy offset: Array<Element>.Offset) -> Element? {
        guard let newIndex = base + offset else { return nil }
        guard newIndex < _count else { return nil }
        if let heapPtr = unsafe _heapPtr {
            return unsafe heapPtr[newIndex.position.rawValue]
        } else {
            return unsafe _inlineReadPointerToElement(at: newIndex.position.rawValue).pointee
        }
    }
}

extension Array.Small where Element: Copyable {
    /// Accesses the element at the given typed index (copy semantics for Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        get {
            precondition(index < _count, "Index out of bounds")
            if let heapPtr = unsafe _heapPtr {
                return unsafe heapPtr[index.position.rawValue]
            } else {
                return unsafe _inlineReadPointerToElement(at: index.position.rawValue).pointee
            }
        }
        set {
            precondition(index < _count, "Index out of bounds")
            if _heapStorage != nil {
                _ = _heapStorage!._moveElement(at: index.position.rawValue)
                _heapStorage!._initializeElement(at: index.position.rawValue, to: newValue)
            } else {
                unsafe _inlinePointerToElement(at: index.position.rawValue).pointee = newValue
            }
        }
    }
}

extension Array.Small where Element: ~Copyable {
    /// Accesses the element at the given typed index (borrowing access for ~Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        _read {
            precondition(index < _count, "Index out of bounds")
            if let heapPtr = unsafe _heapPtr {
                yield unsafe heapPtr[index.position.rawValue]
            } else {
                yield unsafe _inlineReadPointerToElement(at: index.position.rawValue).pointee
            }
        }
        _modify {
            precondition(index < _count, "Index out of bounds")
            if let heapPtr = unsafe _heapPtr {
                yield &(unsafe heapPtr[index.position.rawValue])
            } else {
                yield &(unsafe _inlinePointerToElement(at: index.position.rawValue).pointee)
            }
        }
    }
}

