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

/// Reference-typed element for the refcount-traffic probe rows: copying a
/// storage block of `Payload` retains every slot; tearing one down releases
/// every slot ([BENCH-011]'s wrapper-copy cost model, at element granularity).
final class Payload {
    let value: Int

    init(_ value: Int) {
        self.value = value
    }
}
