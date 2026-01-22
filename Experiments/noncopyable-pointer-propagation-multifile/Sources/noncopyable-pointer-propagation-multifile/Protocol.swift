// ===----------------------------------------------------------------------===//
// FILE: Protocol.swift (protocol definition)
// ===----------------------------------------------------------------------===//
//
// WORKAROUND: Remove `associatedtype Element` from protocol.
// Conformers provide subscript as direct member instead.
//
// ===----------------------------------------------------------------------===//

/// Index-based collection protocol WITHOUT Element associated type.
/// This allows ~Copyable types to conform without implicit Copyable constraints.
public protocol Indexed: ~Copyable {
    associatedtype Index: Equatable

    var startIndex: Index { get }
    var endIndex: Index { get }
    func index(after i: Index) -> Index
    // NOTE: No `associatedtype Element`, no `subscript`
    //       Conformers provide their own subscript directly.
}

// CRITICAL: Protocol extensions must have `where Self: ~Copyable`
extension Indexed where Self: ~Copyable {
    public var isEmpty: Bool { startIndex == endIndex }
}
