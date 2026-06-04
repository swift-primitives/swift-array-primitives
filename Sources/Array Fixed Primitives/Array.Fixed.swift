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

// Note: Array.Fixed is declared INSIDE the Array struct body (in Array.swift)
// due to Swift's ~Copyable constraint propagation rules. This file contains
// only extensions that require internal access to _buffer.

public import Array_Fixed_Primitive
public import Storage_Heap_Primitives
public import Index_Primitives

// MARK: - Initialization (Checked)

extension Array.Fixed {
    /// Creates a fixed array with the specified count, initializing each element.
    ///
    /// - Parameters:
    ///   - count: The number of elements.
    ///   - initializer: A closure that provides the element for each index.
    /// - Throws: `Error.invalidCount` if count is negative.
    @inlinable
    public init(
        count: Array.Index.Count,
        initializingWith initializer: (Array.Index) -> Element
    ) throws(Array.Fixed.Error) {
        guard count >= .zero else {
            throw .invalidCount(count)
        }

        if count == .zero {
            self.init(_buffer: Buffer<Storage<Element>.Heap>.Linear.Bounded(minimumCapacity: .zero))
            return
        }

        let buffer = Buffer<Storage<Element>.Heap>.Linear.Bounded(
            minimumCapacity: count,
            initializingCount: count,
            with: { ptr in
                for i in 0..<Int(bitPattern: count) {
                    let index = Array.Index(Ordinal(UInt(i)))
                    ptr.append(initializer(index))
                }
            }
        )
        self.init(_buffer: buffer)
    }
}

// MARK: - Initialization (Unchecked)

extension Array.Fixed {
    /// Creates a fixed array with the specified count without validation.
    ///
    /// Use this when the count has already been validated by an invariant.
    ///
    /// - Parameters:
    ///   - __unchecked: Marker parameter indicating unchecked operation.
    ///   - count: The number of elements. Must be non-negative.
    ///   - initializer: A closure that provides the element for each index.
    /// - Precondition: `count >= .zero`
    @inlinable
    public init(
        __unchecked: Void,
        count: Array.Index.Count,
        initializingWith initializer: (Array.Index) -> Element
    ) {
        // Count is unsigned, always non-negative by construction

        if count == .zero {
            self.init(_buffer: Buffer<Storage<Element>.Heap>.Linear.Bounded(minimumCapacity: .zero))
            return
        }

        let buffer = Buffer<Storage<Element>.Heap>.Linear.Bounded(
            minimumCapacity: count,
            initializingCount: count,
            with: { ptr in
                for i in 0..<Int(bitPattern: count) {
                    let index = Array.Index(Ordinal(UInt(i)))
                    ptr.append(initializer(index))
                }
            }
        )
        self.init(_buffer: buffer)
    }
}
