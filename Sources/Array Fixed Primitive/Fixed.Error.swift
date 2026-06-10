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

public import Index_Primitives

extension Fixed where S: ~Copyable {
    /// Errors that can occur during fixed array construction.
    public enum Error: Swift.Error, Sendable, Equatable {
        case invalidCount(Index_Primitives.Index<S.Element>.Count)

        /// The index is out of bounds.
        case indexOutOfBounds(index: Index_Primitives.Index<S.Element>, count: Index_Primitives.Index<S.Element>.Count)
    }
}
