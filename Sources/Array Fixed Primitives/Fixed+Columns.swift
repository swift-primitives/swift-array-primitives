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
public import Buffer_Primitive
public import Buffer_Linear_Primitive
public import Buffer_Linear_Bounded_Primitives
public import Storage_Contiguous_Primitives
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Index_Primitives

// MARK: - Construction (pinned to the bounded heap column — the non-growable default)
//
// Every constructor establishes the always-full invariant: it builds a bounded buffer
// with `count == capacity` before wrapping. Pins are `where ==` clauses on initializers
// (mechanic #2).

extension Fixed where S: ~Copyable {
    /// Creates a fixed array with the specified count, initializing each element.
    ///
    /// - Throws: `Error.invalidCount` if count is invalid.
    @inlinable
    public init<E: ~Copyable>(
        count: Index_Primitives.Index<E>.Count,
        initializingWith initializer: (Index_Primitives.Index<E>) -> E
    ) throws(Fixed<S>.Error)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear.Bounded {
        guard count >= .zero else {
            throw .invalidCount(count)
        }
        self.init(__unchecked: (), count: count, initializingWith: initializer)
    }

    /// Creates a fixed array with the specified count without validation.
    ///
    /// - Precondition: `count >= .zero`
    @inlinable
    public init<E: ~Copyable>(
        __unchecked: Void,
        count: Index_Primitives.Index<E>.Count,
        initializingWith initializer: (Index_Primitives.Index<E>) -> E
    )
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear.Bounded {
        if count == .zero {
            self.init(store: Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear.Bounded(minimumCapacity: .zero))
            return
        }
        let buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear.Bounded(
            minimumCapacity: count,
            initializingCount: count,
            with: { ptr in
                for i in 0..<Int(bitPattern: count) {
                    let index = Index_Primitives.Index<E>(Ordinal(UInt(i)))
                    ptr.append(initializer(index))
                }
            }
        )
        self.init(store: buffer)
    }

    /// Creates a fixed array filled with a repeated value.
    @inlinable
    public init<E>(repeating value: E, count: Index_Primitives.Index<E>.Count)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear.Bounded {
        self.init(__unchecked: (), count: count, initializingWith: { _ in value })
    }

    /// Creates a fixed array via an `OutputSpan` closure.
    ///
    /// - Precondition: `initializer` must append exactly `capacity` elements (the
    ///     always-full invariant). Partial initialization triggers a runtime error.
    /// - Throws: Any error thrown by `initializer`, with typed-throws preservation.
    @inlinable
    public init<E: ~Copyable, Failure: Swift.Error>(
        capacity: Index_Primitives.Index<E>.Count,
        initializingWith initializer: (inout Swift.OutputSpan<E>) throws(Failure) -> Void
    ) throws(Failure)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear.Bounded {
        let buffer = try Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear.Bounded(
            capacity: capacity,
            initializingWith: initializer
        )
        precondition(
            buffer.count == capacity,
            "Fixed.init(capacity:initializingWith:) requires the OutputSpan to be fully populated."
        )
        self.init(store: buffer)
    }
}

// MARK: - Mutable span (pinned: not a seam capability)

extension Fixed where S: ~Copyable {
    /// Mutable span of the elements (bounded heap column; form-α method).
    @inlinable
    @_lifetime(&self)
    public mutating func mutableSpan<E: ~Copyable>() -> Swift.MutableSpan<E>
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear.Bounded {
        store.mutableSpan
    }
}

// MARK: - Buffer Access (Escape Hatch for C Interop; bounded heap column)

@_spi(Unsafe)
extension Fixed where S: ~Copyable {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: This is an escape hatch for C interop. Prefer `span` for safe access.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<E, R, Failure: Swift.Error>(
        _ body: (UnsafeBufferPointer<E>) throws(Failure) -> R
    ) throws(Failure) -> R
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear.Bounded {
        try unsafe store.withUnsafeBufferPointer(body)
    }
}
