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
    /// Reference-typed element probes at the mid scale only — these prove the
    /// harness shapes on retain/release-heavy payloads (the W2 element-type
    /// axis), they are not an element-type sweep. `payload.append.zero` is
    /// dominated by the per-element allocation on every subject alike;
    /// `payload.detach` pays n retains per detach plus n releases at the dying
    /// box — the refcount-traffic row [BENCH-011]'s cost model predicts.
    static func payloadCases() -> [Result] {
        var results: [Result] = []
        let n = 1_024

        let buildReps = Swift.max(1, (structureOpsTarget / 8) / n)
        let buildOps = buildReps * n
        let payloadIdxs: [Index<Payload>] = indexStream(n)
        let last = payloadIdxs[n - 1]

        results.append(Result(
            name: "payload.append.zero", subject: "tower.direct", n: n, opsPerBatch: buildOps,
            perOpNs: sample(opsPerBatch: buildOps) {
                var acc = 0
                for _ in 0..<buildReps {
                    var a = MoveArray<Payload>(initialCapacity: .zero)
                    for i in 0..<n { a.append(Payload(i)) }
                    acc &+= a.withElement(at: last) { $0.value }
                }
                sink(acc)
            }
        ))

        results.append(Result(
            name: "payload.append.zero", subject: "tower.cow", n: n, opsPerBatch: buildOps,
            perOpNs: sample(opsPerBatch: buildOps) {
                var acc = 0
                for _ in 0..<buildReps {
                    var c = CoWArray<Payload>(initialCapacity: .zero)
                    for i in 0..<n { c.append(Payload(i)) }
                    acc &+= c.withElement(at: last) { $0.value }
                }
                sink(acc)
            }
        ))

        results.append(Result(
            name: "payload.append.zero", subject: "stdlib", n: n, opsPerBatch: buildOps,
            perOpNs: sample(opsPerBatch: buildOps) {
                var acc = 0
                for _ in 0..<buildReps {
                    var sa: [Payload] = []
                    for i in 0..<n { sa.append(Payload(i)) }
                    acc &+= sa[n - 1].value
                }
                sink(acc)
            }
        ))

        let detachReps = Swift.max(16, (copiedSlotsTarget / 8) / n)
        let first: Index<Payload> = indexStream(n)[0]
        let replacement = Payload(opaque(7))

        var c = CoWArray<Payload>(initialCapacity: count(n))
        for i in 0..<n { c.append(Payload(i)) }
        var sa: [Payload] = []
        sa.reserveCapacity(n)
        for i in 0..<n { sa.append(Payload(i)) }

        results.append(Result(
            name: "payload.detach", subject: "tower.cow", n: n, opsPerBatch: detachReps,
            perOpNs: sample(opsPerBatch: detachReps) {
                var acc = 0
                for _ in 0..<detachReps {
                    var sibling = c
                    sibling[first] = replacement
                    acc &+= sibling.withElement(at: first) { $0.value }
                }
                sink(acc)
            }
        ))

        results.append(Result(
            name: "payload.detach", subject: "stdlib", n: n, opsPerBatch: detachReps,
            perOpNs: sample(opsPerBatch: detachReps) {
                var acc = 0
                for _ in 0..<detachReps {
                    var sibling = sa
                    sibling[0] = replacement
                    acc &+= sibling[0].value
                }
                sink(acc)
            }
        ))

        return results
    }
}
