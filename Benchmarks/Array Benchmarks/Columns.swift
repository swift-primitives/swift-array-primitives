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

import Array_Primitives
import Buffer_Primitive
import Buffer_Linear_Primitive
import Storage_Contiguous_Primitives
import Memory_Heap_Primitives
import Memory_Allocator_Primitive
import Shared_Primitive
import Index_Primitives
import Tagged_Primitives_Standard_Library_Integration
import Ordinal_Primitives
import Ordinal_Primitives_Standard_Library_Integration
import Cardinal_Primitives

// The two ratified columns, spelled exactly as the package's own test suite
// spells them (`Array Surface Tests.swift:18–28`). The Column vocabulary
// module is not a dependency of this package at the granted tip, so the
// bench re-derives the aliases the same way consumers currently do.

typealias HeapColumn<E: ~Copyable> =
    Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear

typealias SharedColumn<E: ~Copyable> = Shared<E, HeapColumn<E>>

typealias MoveArray<E: ~Copyable> = Array<HeapColumn<E>>

typealias CoWArray<E: ~Copyable> = Array<SharedColumn<E>>

extension Bench {
    /// Typed index stream for subscript loops, constructed in setup (outside
    /// every timed region) via the non-throwing `UInt` lane. The tag follows
    /// the subject's element type (`Array.Index = Index<S.Element>`).
    static func indexStream<E>(_ n: Int) -> [Index_Primitives.Index<E>] {
        (0..<n).map { Index_Primitives.Index<E>(Ordinal(UInt($0))) }
    }

    /// Typed count from a runtime size via the non-throwing `UInt` lane.
    static func count<E>(_ n: Int) -> Index_Primitives.Index<E>.Count {
        Index_Primitives.Index<E>.Count(Cardinal(UInt(n)))
    }
}
