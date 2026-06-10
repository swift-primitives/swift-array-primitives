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

extension Array where S: ~Copyable {
    /// Type-safe index for array elements — typed by the COLUMN's element (the user element
    /// on both ratified columns), preventing cross-collection index confusion.
    public typealias Index = Index_Primitives.Index<S.Element>
}
