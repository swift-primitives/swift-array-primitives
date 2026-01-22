// ===----------------------------------------------------------------------===//
// FILE: Protocol.swift (protocol definition)
// ===----------------------------------------------------------------------===//

/// Protocol WITHOUT explicit Element associated type
/// Testing if subscript can still work with inferred Element
public protocol Indexed: ~Copyable {
    associatedtype Index
    associatedtype Element  // Keep this but test conformance

    var startIndex: Index { get }
    var endIndex: Index { get }
    subscript(position: Index) -> Element { get }
    func index(after i: Index) -> Index
}

// ALTERNATIVE: Protocol without Element, using Self.Element constraint
public protocol IndexedNoElement: ~Copyable {
    associatedtype Index

    var startIndex: Index { get }
    var endIndex: Index { get }
    func index(after i: Index) -> Index
    // No subscript - conformers provide their own element access
}
