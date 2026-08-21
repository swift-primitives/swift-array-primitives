public import Array_Primitive
public import Buffer_Linear_Primitive
public import Buffer_Linear_Primitives
public import Buffer_Primitive
public import Index_Primitives
public import Memory_Allocator_Primitive
public import Memory_Allocator_Protocol_Primitives
public import Memory_Heap_Primitives
public import Ownership_Shared_Primitive
public import Storage_Contiguous_Primitives

extension __Array where S: ~Copyable {

    @inlinable
    public mutating func append<E: ~Copyable, Resource: Memory.Growable & ~Copyable>(
        _ element: consuming E
    )
    where S == Buffer<Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Linear {
        store.append(element)
    }

    @inlinable
    public mutating func append<E>(_ element: consuming E)
    where
        S == Ownership.Shared<
            E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear
        >
    {
        store.append(element)
    }

    @inlinable
    public mutating func append<E: ~Copyable>(_ element: consuming E)
    where
        S == Ownership.Shared<
            E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear
        >
    {
        store.appendAssumingUnique(element)
    }
}

extension __Array where S: ~Copyable {

    @inlinable

    public mutating func removeAll<E: ~Copyable, Resource: Memory.Growable & ~Copyable>(
        keepingCapacity: Bool = false
    )
    where S == Buffer<Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Linear {
        store.removeAll(keepingCapacity: keepingCapacity)
    }

    @inlinable

    public mutating func removeAll<E>(keepingCapacity: Bool = false)
    where
        S == Ownership.Shared<
            E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear
        >
    {
        let capacity: Index_Primitives.Index<E>.Count = keepingCapacity ? store.capacity : .zero
        self.store = Ownership.Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear(
                minimumCapacity: capacity
            )
        )
    }
}

extension __Array where S: ~Copyable {

    @inlinable

    public mutating func reserveCapacity<E: ~Copyable, Resource: Memory.Growable & ~Copyable>(
        _ minimumCapacity: Index_Primitives.Index<E>.Count
    )
    where S == Buffer<Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Linear {
        store.reserveCapacity(minimumCapacity)
    }

    @inlinable
    public mutating func reserveCapacity<E>(_ minimumCapacity: Index_Primitives.Index<E>.Count)
    where
        S == Ownership.Shared<
            E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear
        >
    {
        store.reserveCapacity(minimumCapacity)
    }

    @inlinable

    public mutating func reallocate<E: ~Copyable>(
        capacity newCapacity: Index_Primitives.Index<E>.Count
    )
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear {
        store.reallocate(capacity: newCapacity)
    }

    @inlinable
    public mutating func reallocate<E>(capacity newCapacity: Index_Primitives.Index<E>.Count)
    where
        S == Ownership.Shared<
            E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear
        >
    {
        store.reallocate(capacity: newCapacity)
    }
}

extension __Array where S: ~Copyable {

    @inlinable
    public func clone<E>() -> Self
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear {
        Self(store: store.clone())
    }

    @inlinable
    public func clone<E>(capacity: Index_Primitives.Index<E>.Count) -> Self
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear {
        Self(store: store.clone(capacity: capacity))
    }
}

extension __Array where S: ~Copyable {

    @inlinable
    @_lifetime(&self)
    public mutating func mutableSpan<E: ~Copyable>() -> Swift.MutableSpan<E>
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear {
        store.mutableSpan
    }

    @inlinable
    public func withSpan<E, R, Failure: Swift.Error>(
        _ body: (Swift.Span<E>) throws(Failure) -> R
    ) throws(Failure) -> R
    where
        S == Ownership.Shared<
            E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear
        >
    {
        try store.withSpan(body)
    }

    @inlinable
    public mutating func withMutableSpan<E, R, Failure: Swift.Error>(
        _ body: (inout Swift.MutableSpan<E>) throws(Failure) -> R
    ) throws(Failure) -> R
    where
        S == Ownership.Shared<
            E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear
        >
    {
        try store.withMutableSpan(body)
    }
}

@_spi(Unsafe)
extension __Array where S: ~Copyable {

    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<E, R, Failure: Swift.Error>(
        _ body: (UnsafeBufferPointer<E>) throws(Failure) -> R
    ) throws(Failure) -> R
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear {
        try unsafe store.withUnsafeBufferPointer(body)
    }
}
