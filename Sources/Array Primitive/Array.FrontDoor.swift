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

public import Buffer_Linear_Primitive
public import Buffer_Primitive
public import Memory_Allocator_Primitive
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives

// MARK: - Array<E> — the CANONICAL front door ([DS-028])

/// A growable array over the default column: the heap-allocated, move-only contiguous
/// linear buffer.
///
/// This is the canonical front-door alias ([DS-028]) — the sanctioned [API-NAME-004]
/// generic-instantiation exception that pins the default column so consumers spell
/// `Array<Element>`, never the carrier `__Array` or a full column. The alias fully
/// specializes: conformances, the pinned constructors, and `~Copyable` elements all flow
/// through it with zero forwarding and zero runtime cost.
///
/// ```swift
/// var a = Array<Int>(initialCapacity: 4)   // growable move-only (this alias)
/// ```
///
/// Allocation variants are consumer-pulled and land as they gain live consumers. The
/// `Array<Byte>.Small<24>` inline-budget variant ([DS-027].1) lands in its own
/// `Array Small Primitive` target/product (units: `Small<n>` = bytes); the `Shared` (CoW)
/// ownership variant is the `Array<E>.Shared` front door (`Array.Shared.swift`, [DS-028]
/// law 2 — in this canonical target, since the CoW-column module is already in its closure).
///
/// This shadows `Swift.Array`: bare `Array` resolves to this alias when any ecosystem
/// module is imported; use `Swift.Array` or `[T]` syntax for the stdlib array.
public typealias Array<E: ~Copyable> =
    __Array<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear>
