// ===----------------------------------------------------------------------===//
// EXPERIMENT: noncopyable-storage-poisoning
// ===----------------------------------------------------------------------===//
//
// HYPOTHESIS: The errors in Array.swift are caused by one of:
//   1. ManagedBuffer not supporting ~Copyable elements
//   2. Collection.Protocol conformance (where Element: Copyable) poisoning
//      the constraint environment for UnsafeMutablePointer<Element>
//
// METHODOLOGY: [EXP-004a] Incremental Construction
//
// STATUS: IN PROGRESS
// RESULT: TBD
//
// ===----------------------------------------------------------------------===//

// MARK: - Test Type

struct Token: ~Copyable {
    var id: Int
}

// =============================================================================
// VARIANT 1: UnsafeMutablePointer with ~Copyable (baseline)
// =============================================================================

enum V1_Array<Element: ~Copyable>: ~Copyable {
    struct Bounded: ~Copyable {
        var storage: UnsafeMutablePointer<Element>
        let count: Int
    }
}

// =============================================================================
// VARIANT 2: ManagedBuffer with ~Copyable
// =============================================================================

enum V2_Array<Element: ~Copyable>: ~Copyable {
    struct Unbounded: ~Copyable {
        // Attempting to use ManagedBuffer with ~Copyable Element
        final class ElementStorage: ManagedBuffer<Int, Element> {
            static func create(minimumCapacity: Int) -> ElementStorage {
                let storage = ElementStorage.create(minimumCapacity: minimumCapacity) { _ in 0 }
                return unsafeDowncast(storage, to: ElementStorage.self)
            }
        }

        var _storage: ElementStorage
    }
}

// =============================================================================
// VARIANT 3: ~Copyable type CANNOT conform to Sequence
// =============================================================================
// FINDING: Swift.Sequence requires the conforming TYPE to be Copyable.
//          A ~Copyable struct cannot conform to Sequence, period.
//          This is independent of Element type.
//
// Error: "type 'V3_Array<Element>.Bounded' does not conform to protocol 'Copyable'"
//        "type 'V3_Array<Element>.Bounded' does not conform to inherited protocol 'Copyable'"
//
// The swift-array-primitives `Array.Bounded: ~Copyable` CANNOT conform to
// `Sequence.Protocol` or `Collection.Protocol` because those protocols
// require Copyable conforming types.

enum V3_Array<Element: ~Copyable>: ~Copyable {
    struct Bounded: ~Copyable {
        var storage: UnsafeMutablePointer<Element>
        let count: Int
    }
}

// This would fail:
// extension V3_Array.Bounded: Sequence where Element: Copyable { ... }
// Error: type does not conform to inherited protocol 'Copyable'

// =============================================================================
// VARIANT 4: MemoryLayout with ~Copyable
// =============================================================================

enum V4_Array<Element: ~Copyable>: ~Copyable {
    struct Inline: ~Copyable {
        var _count: Int = 0

        // Test if MemoryLayout works with ~Copyable
        var maxElements: Int {
            64 / MemoryLayout<Element>.stride
        }
    }
}

// =============================================================================
// TEST RUNNER
// =============================================================================

print("=== VARIANT 1: UnsafeMutablePointer baseline ===")
let ptr1 = UnsafeMutablePointer<Token>.allocate(capacity: 1)
ptr1.initialize(to: Token(id: 1))
let v1 = V1_Array<Token>.Bounded(storage: ptr1, count: 1)
print("V1 compiled and initialized: count = \(v1.count)")
print("V1 storage[0].id = \(v1.storage[0].id)")
print("✅ V1 PASSED\n")

print("=== VARIANT 2: ManagedBuffer ===")
print("V2 definition compiled, attempting to create instance...")
let v2storage = V2_Array<Token>.Unbounded.ElementStorage.create(minimumCapacity: 4)
print("V2 created: capacity = \(v2storage.capacity)")
print("✅ V2 ManagedBuffer WORKS with ~Copyable!\n")

print("=== VARIANT 3: ~Copyable type cannot conform to Sequence ===")
print("Finding: Swift.Sequence requires conforming TYPE to be Copyable")
print("A ~Copyable struct cannot conform to Sequence at all")
let ptr3 = UnsafeMutablePointer<Token>.allocate(capacity: 1)
ptr3.initialize(to: Token(id: 3))
let v3 = V3_Array<Token>.Bounded(storage: ptr3, count: 1)
print("V3 basic usage works: count = \(v3.count), id = \(v3.storage[0].id)")
print("❌ V3 Sequence conformance NOT POSSIBLE for ~Copyable types\n")

print("=== VARIANT 4: MemoryLayout ===")
let v4 = V4_Array<Token>.Inline()
print("V4 compiled: maxElements = \(v4.maxElements)")
print("✅ V4 PASSED\n")

print(String(repeating: "=", count: 70))
print("SUMMARY")
print(String(repeating: "=", count: 70))
print("""

V1 (UnsafeMutablePointer<~Copyable>): ✅ WORKS
V2 (ManagedBuffer<~Copyable>): ✅ WORKS
V3 (~Copyable type + Sequence): ❌ BLOCKED - Sequence requires Copyable TYPE
V4 (MemoryLayout<~Copyable>): ✅ WORKS

KEY INSIGHT:
  Swift.Sequence and Swift.Collection require the conforming TYPE to be Copyable.
  A struct declared as `~Copyable` cannot conform to these protocols.
  This is a fundamental limitation, NOT a constraint poisoning issue.

IMPLICATIONS FOR swift-array-primitives:
  Array.Bounded, Array.Unbounded, etc. are declared ~Copyable.
  They CANNOT conform to Swift.Sequence or Swift.Collection.
  The +Collection.Access.Random.swift conformances are invalid.

""")
