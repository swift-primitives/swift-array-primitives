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

// Note: Array.Fixed is declared in Array Fixed Primitive. This file contains
// only extensions that require internal access to _buffer.

public import Array_Fixed_Primitive
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Storage_Contiguous_Primitives

// MARK: - Initialization (Checked)

extension Array.Fixed where S: ~Copyable {
    /// Creates a fixed array with the specified count, initializing each element.
    ///
    /// - Parameters:
    ///   - count: The number of elements.
    ///   - initializer: A closure that provides the element for each index.
    /// - Throws: `Error.invalidCount` if count is negative.
    @inlinable
    public init(
        count: Array<S>.Index.Count,
        initializingWith initializer: (Array<S>.Index) -> S.Element
    ) throws(Array<S>.Fixed.Error) {
        guard count >= .zero else {
            throw .invalidCount(count)
        }

        if count == .zero {
            self.init(_buffer: Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<S.Element>>.Linear.Bounded(minimumCapacity: .zero))
            return
        }

        let buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<S.Element>>.Linear.Bounded(
            minimumCapacity: count,
            initializingCount: count,
            with: { ptr in
                for i in 0..<Int(bitPattern: count) {
                    let index = Array<S>.Index(Ordinal(UInt(i)))
                    ptr.append(initializer(index))
                }
            }
        )
        self.init(_buffer: buffer)
    }
}

// MARK: - Initialization (Unchecked)

extension Array.Fixed where S: ~Copyable {
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
        count: Array<S>.Index.Count,
        initializingWith initializer: (Array<S>.Index) -> S.Element
    ) {
        // Count is unsigned, always non-negative by construction

        if count == .zero {
            self.init(_buffer: Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<S.Element>>.Linear.Bounded(minimumCapacity: .zero))
            return
        }

        let buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<S.Element>>.Linear.Bounded(
            minimumCapacity: count,
            initializingCount: count,
            with: { ptr in
                for i in 0..<Int(bitPattern: count) {
                    let index = Array<S>.Index(Ordinal(UInt(i)))
                    ptr.append(initializer(index))
                }
            }
        )
        self.init(_buffer: buffer)
    }
}
