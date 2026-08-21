public import Buffer_Linear_Primitive
public import Buffer_Primitive
public import Index_Primitives
public import Memory_Allocator_Primitive
public import Memory_Allocator_Protocol_Primitives
public import Memory_Heap_Primitives
public import Ownership_Shared_Primitive
public import Storage_Contiguous_Primitives

@_documentation(visibility: public)
@frozen
public struct __Array<S: ~Copyable>: ~Copyable {

    @usableFromInline
    package var store: S

    @inlinable
    public init(store: consuming S) {
        self.store = store
    }

}

extension __Array where S: ~Copyable {

    @inlinable
    public consuming func take() -> S {
        store
    }
}

extension __Array: Copyable where S: Copyable {}

extension __Array: Sendable where S: Sendable & ~Copyable {}

extension __Array where S: ~Copyable {

    @inlinable

    public init<E: ~Copyable, Resource: Memory.Growable & ~Copyable>(
        initialCapacity: Index_Primitives.Index<E>.Count = .zero
    )
    where S == Buffer<Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Linear {
        self.init(store: S(minimumCapacity: initialCapacity))
    }

    @inlinable
    public init<E>(initialCapacity: Index_Primitives.Index<E>.Count = .zero)
    where
        S == Ownership.Shared<
            E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear
        >
    {
        self.init(
            store: Ownership.Shared(
                Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear(
                    minimumCapacity: initialCapacity
                )
            )
        )
    }

    @inlinable

    public init<E: ~Copyable>(initialCapacity: Index_Primitives.Index<E>.Count = .zero)
    where
        S == Ownership.Shared<
            E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear
        >
    {
        self.init(
            store: Ownership.Shared(
                Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear(
                    minimumCapacity: initialCapacity
                )
            )
        )
    }
}
