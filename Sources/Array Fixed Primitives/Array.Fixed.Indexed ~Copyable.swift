//
//  File.swift
//  swift-array-primitives
//
//  Created by Coen ten Thije Boonkkamp on 24/01/2026.
//

import Array_Primitives_Core

// MARK: - Sendable
extension Array.Fixed.Indexed: @unchecked Sendable where Element: Sendable, Tag: ~Copyable {}
