public import Array_Primitive
public import Array_Protocol_Primitives
public import Buffer_Linear_Primitives
public import Buffer_Protocol_Primitives
public import Iterable
public import Iterator_Chunk_Primitives
public import Span_Protocol_Primitives
public import Store_Protocol_Primitives

extension __Array: Collection.Access.Random
where S: Span.`Protocol` & Store.`Protocol` & Buffer.`Protocol` & ~Copyable {}

extension __Array where S: ~Copyable {

    public typealias Dynamic = Self
}

extension __Array: Span.`Protocol` where S: Span.`Protocol` & ~Copyable {

    @inlinable
    public var span: Swift.Span<S.Element> {
        @_lifetime(borrow self)
        borrowing get {
            store.span
        }
    }
}

extension __Array: Iterable where S: Span.`Protocol` & ~Copyable {

    @_implements(Iterable,Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Chunk<S.Element>
}

extension __Array: Sequenceable where S: Sequenceable & ~Copyable, S.Iterator: Escapable {

    @_implements(Sequenceable,Iterator)
    public typealias SequenceableIterator = S.Iterator

    @inlinable
    public consuming func makeIterator() -> S.Iterator {
        take().makeIterator()
    }
}
