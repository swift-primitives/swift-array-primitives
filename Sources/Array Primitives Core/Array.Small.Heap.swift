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

extension Array.Small where Element: ~Copyable {
    /// Namespace for heap-related types.
    ///
    /// Contains:
    /// - `Heap.State`: Storage reference with cached pointer (used as stored property)
    /// - `Heap.View`: Non-escapable accessor for heap operations (in Array Small Primitives)
    @frozen
    public enum Heap {}
}
