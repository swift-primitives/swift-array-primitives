public import Collection_Primitives

// ===----------------------------------------------------------------------===//
// IMPORTANT: Sequence.Protocol and Collection.Protocol conformances REMOVED
// ===----------------------------------------------------------------------===//
//
// These conformances caused constraint poisoning errors:
//   "type 'Element' does not conform to protocol 'Copyable'"
//   on UnsafeMutablePointer<Element> and ManagedBuffer in Array.swift
//
// ROOT CAUSE (confirmed via experiments):
//   Having conditional conformances like `where Element: Copyable` on types
//   that are themselves `~Copyable` causes the compiler to incorrectly
//   propagate Copyable requirements to the base type definition.
//
// WORKAROUND:
//   - Use Collection.Indexed and Collection.Bidirectional for index-based access
//   - Use direct forEach methods for iteration
//   - Sequence/Collection protocol conformance not available for ~Copyable array types
//
// See: swift-array-primitives/Experiments/noncopyable-multifile-poisoning/
// ===----------------------------------------------------------------------===//

// NOTE: Iterator, Sequence.Protocol, Collection.Protocol, and Collection.Access.Random
// conformances have been removed due to constraint poisoning issues.
// The array types provide direct subscript and forEach methods instead.
