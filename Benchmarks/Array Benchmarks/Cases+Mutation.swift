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
    /// `set.indexed`: per-element writes through the subscript's `_modify` —
    /// the column's mutation gate runs on EVERY write (no-op on the direct
    /// column; an always-unique `isKnownUniquelyReferenced` branch on the
    /// `Shared` column — the R4 worst-case shape, here through the real
    /// family). `set.span`: the sanctioned bulk idiom — gate once, then raw
    /// span writes. Arrays are unique throughout (no sibling values), so the
    /// CoW gate always takes its cheap true branch and never detaches.
    static func mutationCases() -> [Result] {
        var results: [Result] = []
        for n in sizes {
            let passes = Swift.max(1, elementOpsTarget / n)
            let ops = passes * n
            let spanPasses = Swift.max(1, spanOpsTarget / n)
            let spanOps = spanPasses * n
            let idxs: [Index<Int>] = indexStream(n)
            let ints = [Int](0..<n)
            let first = idxs[0]
            let v = opaque(7)

            var a = MoveArray<Int>(initialCapacity: count(n))
            for i in 0..<n { a.append(i) }
            var c = CoWArray<Int>(initialCapacity: count(n))
            for i in 0..<n { c.append(i) }
            var sa: [Int] = []
            sa.reserveCapacity(n)
            for i in 0..<n { sa.append(i) }

            results.append(Result(
                name: "set.indexed", subject: "tower.direct", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    for _ in 0..<passes {
                        for idx in idxs { a[idx] = v }
                    }
                    sink(a[first])
                }
            ))

            results.append(Result(
                name: "set.indexed", subject: "tower.cow", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    for _ in 0..<passes {
                        for idx in idxs { c[idx] = v }
                    }
                    sink(c[first])
                }
            ))

            results.append(Result(
                name: "set.indexed", subject: "stdlib", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    for _ in 0..<passes {
                        for i in ints { sa[i] = v }
                    }
                    sink(sa[0])
                }
            ))

            results.append(Result(
                name: "set.span", subject: "tower.direct", n: n, opsPerBatch: spanOps,
                perOpNs: sample(opsPerBatch: spanOps) {
                    for _ in 0..<spanPasses {
                        var ms = a.mutableSpan()
                        for i in 0..<n { ms[i] = v }
                    }
                    sink(a[first])
                }
            ))

            results.append(Result(
                name: "set.span", subject: "tower.cow", n: n, opsPerBatch: spanOps,
                perOpNs: sample(opsPerBatch: spanOps) {
                    for _ in 0..<spanPasses {
                        c.withMutableSpan { ms in
                            for i in 0..<n { ms[i] = v }
                        }
                    }
                    sink(c[first])
                }
            ))

            results.append(Result(
                name: "set.span", subject: "stdlib", n: n, opsPerBatch: spanOps,
                perOpNs: sample(opsPerBatch: spanOps) {
                    for _ in 0..<spanPasses {
                        var ms = sa.mutableSpan
                        for i in 0..<n { ms[i] = v }
                    }
                    sink(sa[0])
                }
            ))
        }
        return results
    }
}
