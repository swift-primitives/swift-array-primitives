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
    /// `append.zero`: n appends starting from zero capacity (growth policy
    /// included), and `append.reserved`: n appends into pre-sized storage
    /// (growth policy excluded). Each rep builds and tears down one array;
    /// teardown is inside the batch on every subject alike.
    static func appendCases() -> [Result] {
        var results: [Result] = []
        for n in sizes {
            let reps = Swift.max(1, structureOpsTarget / n)
            let ops = reps * n
            let seed = opaque(1)
            let idxs: [Index<Int>] = indexStream(n)
            let last = idxs[n - 1]

            results.append(Result(
                name: "append.zero", subject: "tower.direct", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var acc = 0
                    for _ in 0..<reps {
                        var a = MoveArray<Int>(initialCapacity: .zero)
                        for i in 0..<n { a.append(i &+ seed) }
                        acc &+= a[last]
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "append.zero", subject: "tower.cow", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var acc = 0
                    for _ in 0..<reps {
                        var c = CoWArray<Int>(initialCapacity: .zero)
                        for i in 0..<n { c.append(i &+ seed) }
                        acc &+= c[last]
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "append.zero", subject: "stdlib", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var acc = 0
                    for _ in 0..<reps {
                        var sa: [Int] = []
                        for i in 0..<n { sa.append(i &+ seed) }
                        acc &+= sa[n - 1]
                    }
                    sink(acc)
                }
            ))

            let capacity: Index<Int>.Count = count(n)

            results.append(Result(
                name: "append.reserved", subject: "tower.direct", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var acc = 0
                    for _ in 0..<reps {
                        var a = MoveArray<Int>(initialCapacity: capacity)
                        for i in 0..<n { a.append(i &+ seed) }
                        acc &+= a[last]
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "append.reserved", subject: "tower.cow", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var acc = 0
                    for _ in 0..<reps {
                        var c = CoWArray<Int>(initialCapacity: capacity)
                        for i in 0..<n { c.append(i &+ seed) }
                        acc &+= c[last]
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "append.reserved", subject: "stdlib", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var acc = 0
                    for _ in 0..<reps {
                        var sa: [Int] = []
                        sa.reserveCapacity(n)
                        for i in 0..<n { sa.append(i &+ seed) }
                        acc &+= sa[n - 1]
                    }
                    sink(acc)
                }
            ))
        }
        return results
    }
}
