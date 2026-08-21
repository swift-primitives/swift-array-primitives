import Array_Primitive
public import Collection_Primitives

@_documentation(visibility: public)
public protocol Indexable: Collection.Bidirectional & ~Copyable {

    var count: Index_Primitives.Index<Element>.Count { get }

    subscript(_ position: Index) -> Element { get set }
}

public typealias __ArrayProtocol = Indexable
