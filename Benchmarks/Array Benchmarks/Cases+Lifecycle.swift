// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Array_Primitives
import Buffer_Primitive
import Buffer_Linear_Primitive
import Storage_Contiguous_Primitives
import Memory_Heap_Primitives
import Memory_Allocator_Primitive
import Shared_Primitive
import Index_Primitives
import Tagged_Primitives_Standard_Library_Integration
import Ordinal_Primitives
import Ordinal_Primitives_Standard_Library_Integration
import Cardinal_Primitives

extension Bench {
    /// `pushPop.cycle`: n appends into pre-sized storage, then n `removeLast`
    /// pops, per rep (per-op = one push or one pop; the `append.reserved`
    /// numbers act as the build-only control for separating the pop cost).
    ///
    /// `detach.firstMutation` (per-op unit = ONE detach at size n): make a
    /// sibling copy, write one element through the gate — the not-unique
    /// branch detaches the full n-element storage; the sibling's box dies in
    /// the same op. `clone.explicit` (per-op unit = ONE clone at size n) is
    /// the direct column's explicit deep copy, the move-only counterpart row.
    static func lifecycleCases() -> [Result] {
        var results: [Result] = []

        for n in sizes {
            let reps = Swift.max(1, structureOpsTarget / n)
            let ops = reps * 2 * n
            let seed = opaque(1)
            let capacity: Index<Int>.Count = count(n)

            results.append(Result(
                name: "pushPop.cycle", subject: "tower.direct", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var acc = 0
                    for _ in 0..<reps {
                        var a = MoveArray<Int>(initialCapacity: capacity)
                        for i in 0..<n { a.append(i &+ seed) }
                        for _ in 0..<n { acc &+= a.removeLast() }
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "pushPop.cycle", subject: "tower.cow", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var acc = 0
                    for _ in 0..<reps {
                        var c = CoWArray<Int>(initialCapacity: capacity)
                        for i in 0..<n { c.append(i &+ seed) }
                        for _ in 0..<n { acc &+= c.removeLast() }
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "pushPop.cycle", subject: "stdlib", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var acc = 0
                    for _ in 0..<reps {
                        var sa: [Int] = []
                        sa.reserveCapacity(n)
                        for i in 0..<n { sa.append(i &+ seed) }
                        for _ in 0..<n { acc &+= sa.removeLast() }
                    }
                    sink(acc)
                }
            ))
        }

        // Detach and clone scale with n; the per-op unit is one whole-array
        // copy, so n = 16 is dropped (clock-granularity noise, no information).
        for n in sizes.dropFirst() {
            let reps = Swift.max(16, copiedSlotsTarget / n)
            let v = opaque(7)
            let first: Index<Int> = indexStream(n)[0]

            var c = CoWArray<Int>(initialCapacity: count(n))
            for i in 0..<n { c.append(i) }
            var sa: [Int] = []
            sa.reserveCapacity(n)
            for i in 0..<n { sa.append(i) }

            results.append(Result(
                name: "detach.firstMutation", subject: "tower.cow", n: n, opsPerBatch: reps,
                perOpNs: sample(opsPerBatch: reps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var sibling = c
                        sibling[first] = v
                        acc &+= sibling[first]
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "detach.firstMutation", subject: "stdlib", n: n, opsPerBatch: reps,
                perOpNs: sample(opsPerBatch: reps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var sibling = sa
                        sibling[0] = v
                        acc &+= sibling[0]
                    }
                    sink(acc)
                }
            ))

            var a = MoveArray<Int>(initialCapacity: count(n))
            for i in 0..<n { a.append(i) }

            results.append(Result(
                name: "clone.explicit", subject: "tower.direct", n: n, opsPerBatch: reps,
                perOpNs: sample(opsPerBatch: reps) {
                    var acc = 0
                    for _ in 0..<reps {
                        let b = a.clone()
                        acc &+= b[first]
                    }
                    sink(acc)
                }
            ))
        }

        return results
    }
}
