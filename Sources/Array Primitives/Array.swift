// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif os(Windows)
    import ucrt
    import WinSDK
#endif

// MARK: - Global Sentinel for Empty Containers

/// Process-global sentinel pointer for empty containers.
///
/// ## Safety Rationale
///
/// Using a globally-allocated sentinel instead of `bitPattern` provides defense in depth:
/// - If an invariant is violated and the pointer is dereferenced, it points to valid memory
/// - `bitPattern` would give undefined behavior if dereferenced
/// - Matches Swift stdlib pattern (`_emptyBufferStorage`)
/// - Allocation is negligible (one global per process, amortized to zero)
///
/// Page-aligned pointer dominates all power-of-two alignments (1, 2, 4, 8, 16, ...).
/// For any `Element` type with standard alignment, this sentinel satisfies alignment requirements.
/// Allocated once at process start; never freed.
@usableFromInline
nonisolated(unsafe) let _emptyContainerSentinel: UnsafeMutableRawPointer = {
    #if os(Windows)
        var info = SYSTEM_INFO()
        GetSystemInfo(&info)
        let pageSize = Int(info.dwPageSize)
        guard let raw = unsafe _aligned_malloc(1, pageSize) else {
            fatalError("Failed to allocate empty container sentinel")
        }
        return unsafe raw
    #else
        let pageSize = sysconf(Int32(_SC_PAGESIZE))
        let alignment = pageSize > 0 ? Int(pageSize) : 4096
        var raw: UnsafeMutableRawPointer?
        let result = unsafe posix_memalign(&raw, alignment, 1)
        guard result == 0, let p = unsafe raw else {
            fatalError("Failed to allocate empty container sentinel")
        }
        return unsafe p
    #endif
}()

/// Namespace for fixed-capacity array types.
///
/// This shadows `Swift.Array`. Use `Swift.Array` or `Array_Primitives.Array`
/// to disambiguate when both are in scope.
public enum Array<Element: ~Copyable>: ~Copyable {}
