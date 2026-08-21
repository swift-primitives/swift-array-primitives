public import Array_Primitive
public import Buffer_Linear_Primitive
public import Buffer_Primitive
public import Memory_Allocator_Primitive
public import Memory_Small_Primitives
public import Storage_Contiguous_Primitives
public import Store_Protocol_Primitives

extension __Array where S: ~Copyable, S: Store.Direct {

    public typealias Small<let n: Int> =
        __Array<Buffer<Storage<Memory.Allocator<Memory.Small<n>>>.Contiguous<S.Element>>.Linear>
}
