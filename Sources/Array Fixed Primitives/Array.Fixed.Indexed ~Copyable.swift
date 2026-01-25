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

import Array_Primitives_Core

// MARK: - Sendable
extension Array.Fixed.Indexed: @unchecked Sendable where Element: Sendable, Tag: ~Copyable {}
