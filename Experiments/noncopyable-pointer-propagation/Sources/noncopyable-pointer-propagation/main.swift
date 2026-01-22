// ===----------------------------------------------------------------------===//
// EXPERIMENT: noncopyable-pointer-propagation
// ===----------------------------------------------------------------------===//
//
// HYPOTHESIS: UnsafeMutablePointer<Element> fails in nested types when protocol
//             conformances exist in separate files, due to ~Copyable constraint
//             propagation failure.
//
// METHODOLOGY: [EXP-004a] Incremental Construction
//
// STATUS: CONFIRMED
// RESULT: FUNDAMENTAL LANGUAGE LIMITATION IDENTIFIED
//
// ===----------------------------------------------------------------------===//
//
// ## Summary
//
// The build failure in swift-array-primitives is NOT caused by:
// - UnsafePointer/UnsafeMutablePointer lacking ~Copyable support (SE-0437 fixed this)
// - Multi-file constraint propagation (this is a symptom, not the cause)
//
// The failure IS caused by:
// - Swift does NOT allow `associatedtype Element: ~Copyable` on protocols
// - Collection.Indexed has `associatedtype Element` without ~Copyable suppression
// - When a type with `Element: ~Copyable` conforms to such a protocol,
//   the compiler cannot satisfy the implicit `Element: Copyable` requirement
//
// ## Reproduction
//
// See companion experiment: noncopyable-pointer-propagation-multifile/
//
// | Protocol | associatedtype Element | ~Copyable type conforms? |
// |----------|----------------------|-------------------------|
// | IndexedNoElement | No | ✅ Yes |
// | Indexed | Yes (implicit Copyable) | ❌ No |
//
// ## Error Message
//
// error: type 'Array<Element>.Bounded' does not conform to protocol 'Indexed'
// note: candidate can not infer 'Element' = 'Element' because 'Element' is
//       not a nominal type and so can't conform to 'Copyable'
// note: unable to infer associated type 'Element' for protocol 'Indexed'
//
// ## Why Does the Error Appear on UnsafeMutablePointer?
//
// The error manifests on `var storage: UnsafeMutablePointer<Element>` in
// Array.swift because:
//
// 1. Array.Bounded+Collection.Indexed.swift conforms to Collection.Indexed
// 2. Collection.Indexed has `associatedtype Element` (implicit Copyable)
// 3. The conformance extension gets implicit `where Element: Copyable`
// 4. This "poisons" the constraint environment during module emission
// 5. The stored property declaration (in a different file!) fails because
//    the constraint solver now thinks Element must be Copyable
//
// This is [MEM-COPY-006] Category 3 manifesting through the associated type.
//
// ## Swift Language Status
//
// | Feature | Status | Reference |
// |---------|--------|-----------|
// | UnsafePointer<~Copyable> | ✅ Supported (Swift 6.0) | SE-0437 |
// | associatedtype X: ~Copyable | ❌ NOT SUPPORTED | Language limitation |
// | Protocol with associatedtype + ~Copyable conformer | ❌ BLOCKED | Depends on above |
//
// ## Workarounds
//
// 1. **Remove associatedtype Element from protocol**: If the protocol doesn't
//    need Element as an associated type, remove it. Conformers provide their
//    own subscript without protocol constraint.
//
// 2. **Don't conform to protocols with associatedtype**: For types with
//    ~Copyable elements, avoid conforming to protocols that have associated
//    types (unless those associated types don't involve the element type).
//
// 3. **Use direct methods instead of protocol conformance**: Per [MEM-COPY-006]
//    Category 4, use forEach(_:) with borrowing closures instead of protocol-
//    based iteration.
//
// ## Recommendations for swift-array-primitives
//
// Option A: Remove Collection.Indexed conformance
// - Array.Bounded, Array.Unbounded etc. cannot conform to Collection.Indexed
//   when Element: ~Copyable because Collection.Indexed has associatedtype Element
// - Provide direct index-based methods instead (startIndex, endIndex, subscript)
//   without protocol conformance
//
// Option B: Conditional conformance only for Copyable
// - Add: `extension Array.Bounded: Collection.Indexed where Element: Copyable`
// - This limits protocol-based iteration to Copyable elements only
// - ~Copyable elements use direct forEach/withElement methods
//
// Option C: Wait for Swift to support `associatedtype Element: ~Copyable`
// - This is a language evolution item, timeline unknown
//
// ===----------------------------------------------------------------------===//

print("See experiment documentation above for findings.")
print("Run noncopyable-pointer-propagation-multifile for live reproduction.")
