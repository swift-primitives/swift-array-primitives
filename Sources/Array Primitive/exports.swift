// exports.swift
// Array Primitive declares the hoisted carrier `struct __Array<S: ~Copyable>` (the ADT
// over an explicit storage COLUMN, [DS-025]) + the canonical front door `Array<E>`
// ([DS-028]) + `Array.Index` + `take()` + the pinned column constructors.
// Per the exports-narrowing ruling (audit #9, 2026-06-10), nothing is re-exported:
// consumers SPELL their column by importing the column-vocabulary modules explicitly
// (Buffer/Storage/Memory/Shared/Index).
