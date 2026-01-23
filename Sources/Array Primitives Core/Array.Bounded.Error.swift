//
//  File.swift
//  swift-array-primitives
//
//  Created by Coen ten Thije Boonkkamp on 23/01/2026.
//

extension Array.Fixed {
    /// Errors that can occur during bounded array operations.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The requested count is invalid (negative).
        case invalidCount(Int)

        /// The index is out of bounds.
        case indexOutOfBounds(index: Index_Primitives.Index<Element>, count: Index_Primitives.Index<Element>.Count)
    }
}
