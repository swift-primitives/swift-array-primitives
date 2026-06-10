// exports.swift
// Array Primitive declares `struct Array<S>` (the ADT over an explicit storage COLUMN)
// + `Array.Index` + `take()`. Per the exports-narrowing ruling (audit #9, 2026-06-10),
// nothing is re-exported: consumers SPELL their column by importing the column-vocabulary
// modules explicitly (Buffer/Storage/Memory/Shared/Index).
