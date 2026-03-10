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

import Testing
@testable import Array_Primitives

@Suite("Array - Deinit")
struct ArrayDeinitTests {

    final class Tracker: @unchecked Sendable {
        private var _storage: [Int] = []
        var deinitCount: Int { _storage.count }
        var deinitOrder: [Int] { _storage }
        func append(_ id: Int) { _storage.append(id) }
    }

    struct TrackedElement: ~Copyable {
        let id: Int
        let tracker: Tracker
        init(_ id: Int, tracker: Tracker) { self.id = id; self.tracker = tracker }
        deinit { tracker.append(id) }
    }

    // MARK: - Array.Static

    @Test
    func `Static deinit destroys all elements`() throws {
        let tracker = Tracker()
        do {
            var array = Array<TrackedElement>.Static<4>()
            try array.append(TrackedElement(1, tracker: tracker))
            try array.append(TrackedElement(2, tracker: tracker))
            try array.append(TrackedElement(3, tracker: tracker))
        }
        #expect(tracker.deinitCount == 3)
    }

    @Test
    func `Static empty deinit does not crash`() {
        do {
            let _ = Array<TrackedElement>.Static<4>()
        }
    }

    // MARK: - Array.Small

    @Test
    func `Small deinit destroys all elements in inline mode`() {
        let tracker = Tracker()
        do {
            var array = Array<TrackedElement>.Small<4>()
            array.append(TrackedElement(1, tracker: tracker))
            array.append(TrackedElement(2, tracker: tracker))
            array.append(TrackedElement(3, tracker: tracker))
        }
        #expect(tracker.deinitCount == 3)
    }

    @Test
    func `Small deinit destroys all elements after spill`() {
        let tracker = Tracker()
        do {
            var array = Array<TrackedElement>.Small<2>()
            array.append(TrackedElement(1, tracker: tracker))
            array.append(TrackedElement(2, tracker: tracker))
            // Spill to heap
            array.append(TrackedElement(3, tracker: tracker))
            array.append(TrackedElement(4, tracker: tracker))
        }
        #expect(tracker.deinitCount == 4)
    }

    @Test
    func `Small empty deinit does not crash`() {
        do {
            let _ = Array<TrackedElement>.Small<4>()
        }
    }
}
