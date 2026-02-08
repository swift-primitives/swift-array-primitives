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

public import Algebra_Modular_Primitives

// MARK: - Bounded Index

extension Array.Bounded where Element: ~Copyable {
    /// Type-safe bounded index for bounded array elements.
    ///
    /// Uses `Algebra.Z<N>` to provide compile-time bounds safety,
    /// ensuring indices are always valid for this array's dimension.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let idx: Array<Int>.Bounded<3>.Index = try! .init(0)
    /// var arr = Array<Int>.Bounded<3>([1, 2, 3])
    /// print(arr[idx])  // 1
    /// ```
    public typealias Index = Algebra.Z<N>
}
