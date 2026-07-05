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

/// Family-tier proving benchmark for swift-array-primitives (arc-bench W1).
///
/// MEASUREMENT DISCIPLINE (the arc GOAL + [BENCH-002]): run release-only via
/// `swift run -c release "Array Benchmarks"` after `rm -rf .build`; never via
/// `swift test`. Machine identity, toolchain, and run conditions are recorded
/// by the runner shell and the baselines doc, not introspected here (the
/// primitives tier is Foundation-free, [PRIM-FOUND-001]).
@main
enum Main {
    static func main() {
        print("=== swift-array-primitives — family-tier proving benchmark (W1) ===")
        print("config: sizes=\(Bench.sizes) samples=\(Bench.samples) warmup=\(Bench.warmup)")
        print("targets/sample: element=\(Bench.elementOpsTarget) span=\(Bench.spanOpsTarget) structure=\(Bench.structureOpsTarget) copiedSlots=\(Bench.copiedSlotsTarget)")
        print("subjects: tower.direct=Array<HeapColumn> · tower.cow=Array<Ownership.Shared<E,HeapColumn>> · stdlib=Swift.Array")
        print("")
        Bench.globalWarmup()

        var results: [Bench.Result] = []
        for group in [Bench.appendCases, Bench.accessCases, Bench.mutationCases, Bench.lifecycleCases, Bench.payloadCases] {
            let groupResults = group()
            for result in groupResults {
                print(result.record)
            }
            results.append(contentsOf: groupResults)
        }

        print("")
        print(summaryTable(results))
        Bench.flushSink()
    }

    /// Aligned median (cv%) table: one row per shape × scale, one column per
    /// subject. Raw per-sample vectors live in the BENCH record lines above.
    static func summaryTable(_ results: [Bench.Result]) -> String {
        let subjects = ["tower.direct", "tower.cow", "stdlib"]
        var rowKeys: [String] = []
        var cells: [String: [String: String]] = [:]
        for r in results {
            let key = "\(r.name) n=\(r.n)"
            if cells[key] == nil {
                rowKeys.append(key)
                cells[key] = [:]
            }
            cells[key]![r.subject] = "\(Bench.fixed(r.median, 2)) (\(Bench.fixed(r.cvPercent, 1))%)"
        }

        let nameWidth = rowKeys.map(\.count).max() ?? 0
        let columnWidth = 20
        var lines: [String] = []
        lines.append(pad("shape", nameWidth) + subjects.map { pad($0, columnWidth) }.joined())
        lines.append(String(repeating: "-", count: nameWidth + columnWidth * subjects.count))
        for key in rowKeys {
            let row = subjects.map { pad(cells[key]?[$0] ?? "-", columnWidth) }.joined()
            lines.append(pad(key, nameWidth) + row)
        }
        lines.append("")
        lines.append("unit: ns/op, median across \(Bench.samples) samples (cv%); per-op = batch / opsPerBatch")
        lines.append("detach/clone rows: one op = one whole-array copy at the row's n")
        return lines.joined(separator: "\n")
    }

    static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text + " " : text + String(repeating: " ", count: width - text.count)
    }
}
