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
    /// `get.indexed`: sequential read sum through the subscript, driven by a
    /// precomputed index stream (typed indices for the tower, `Int` for the
    /// stdlib — each subject pays one stream read plus one subscript per op).
    /// `get.span`: sequential read sum through the span (`Int`-indexed on
    /// every subject; no typed-index construction anywhere on the path).
    /// Arrays are built once per scale, outside every timed region.
    static func accessCases() -> [Result] {
        var results: [Result] = []
        for n in sizes {
            let passes = Swift.max(1, elementOpsTarget / n)
            let ops = passes * n
            let spanPasses = Swift.max(1, spanOpsTarget / n)
            let spanOps = spanPasses * n
            let idxs: [Index<Int>] = indexStream(n)
            let ints = [Int](0..<n)

            var a = MoveArray<Int>(initialCapacity: count(n))
            for i in 0..<n { a.append(i) }
            var c = CoWArray<Int>(initialCapacity: count(n))
            for i in 0..<n { c.append(i) }
            var sa: [Int] = []
            sa.reserveCapacity(n)
            for i in 0..<n { sa.append(i) }

            results.append(Result(
                name: "get.indexed", subject: "tower.direct", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var sum = 0
                    for _ in 0..<passes {
                        for idx in idxs { sum &+= a[idx] }
                    }
                    sink(sum)
                }
            ))

            results.append(Result(
                name: "get.indexed", subject: "tower.cow", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var sum = 0
                    for _ in 0..<passes {
                        for idx in idxs { sum &+= c[idx] }
                    }
                    sink(sum)
                }
            ))

            results.append(Result(
                name: "get.indexed", subject: "stdlib", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var sum = 0
                    for _ in 0..<passes {
                        for i in ints { sum &+= sa[i] }
                    }
                    sink(sum)
                }
            ))

            results.append(Result(
                name: "get.span", subject: "tower.direct", n: n, opsPerBatch: spanOps,
                perOpNs: sample(opsPerBatch: spanOps) {
                    var sum = 0
                    for _ in 0..<spanPasses {
                        let s = a.span
                        for i in 0..<n { sum &+= s[i] }
                    }
                    sink(sum)
                }
            ))

            results.append(Result(
                name: "get.span", subject: "tower.cow", n: n, opsPerBatch: spanOps,
                perOpNs: sample(opsPerBatch: spanOps) {
                    var sum = 0
                    for _ in 0..<spanPasses {
                        let s = c.span
                        for i in 0..<n { sum &+= s[i] }
                    }
                    sink(sum)
                }
            ))

            results.append(Result(
                name: "get.span", subject: "stdlib", n: n, opsPerBatch: spanOps,
                perOpNs: sample(opsPerBatch: spanOps) {
                    var sum = 0
                    for _ in 0..<spanPasses {
                        let s = sa.span
                        for i in 0..<n { sum &+= s[i] }
                    }
                    sink(sum)
                }
            ))

        }
        return results
    }
}
