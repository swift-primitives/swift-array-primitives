//
//  File.swift
//  swift-array-primitives
//
//  Created by Coen ten Thije Boonkkamp on 23/01/2026.
//

public import Array_Primitive

extension Array.Fixed where S: ~Copyable {
    /// Errors that can occur during fixed array operations.
    public enum Error: Swift.Error, Sendable, Equatable {
        case invalidCount(Array<S>.Index.Count)

        /// The index is out of bounds.
        case indexOutOfBounds(index: Array<S>.Index, count: Array<S>.Index.Count)
    }
}
