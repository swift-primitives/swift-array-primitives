public import Buffer_Linear_Primitive
public import Buffer_Primitive
public import Memory_Allocator_Primitive
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives

public typealias Array<E: ~Copyable> =
    __Array<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear>
