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

public import Array_Fixed_Primitive
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Storage_Contiguous_Primitives

// MARK: - Array.Fixed + OutputSpan-based initializer

extension Array.Fixed where S: ~Copyable {

    /// Creates a fixed array with the specified capacity, initialized via an
    /// `OutputSpan` closure.
    ///
    /// This initializer matches the shape of `Swift.Array.init(capacity:initializingWith:)`
    /// and SE-0527's `RigidArray` construction idiom, enabling ~Copyable elements to be
    /// placed directly into storage without requiring a per-index closure that returns
    /// elements by value.
    ///
    /// ## Invariant enforcement
    ///
    /// `Array.Fixed` guarantees that every slot is initialized. The initializer
    /// closure MUST append exactly `capacity` elements to the `OutputSpan`.
    /// Partial initialization violates the invariant and triggers a runtime error.
    ///
    /// If you need a variable-count heap array, use ``Array`` (dynamic) with its
    /// OutputSpan-based init instead.
    ///
    /// ## Throwing behavior
    ///
    /// If the initializer throws, elements successfully initialized before the
    /// throw are deinitialized by the `OutputSpan`'s deinit; the error propagates
    /// to the caller; the `Array.Fixed` is not constructed.
    ///
    /// - Parameters:
    ///   - capacity: The number of elements the array will hold. The `OutputSpan`
    ///       passed to the initializer covers exactly this many slots.
    ///   - initializer: A closure that populates all `capacity` slots via an
    ///       `OutputSpan`. Called at most once.
    ///
    /// - Precondition: `initializer` must append exactly `capacity` elements.
    ///     Partial initialization triggers a runtime error.
    /// - Throws: Any error thrown by `initializer`, with typed-throws preservation.
    @inlinable
    public init<Failure: Swift.Error>(
        capacity: Array<S>.Index.Count,
        initializingWith initializer: (inout Swift.OutputSpan<S.Element>) throws(Failure) -> Void
    ) throws(Failure) {
        let buffer = try Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<S.Element>>.Linear.Bounded(
            capacity: capacity,
            initializingWith: initializer
        )
        precondition(
            buffer.count == capacity,
            "Array.Fixed.init(capacity:initializingWith:) requires the OutputSpan to be fully populated."
        )
        self.init(_buffer: buffer)
    }
}
