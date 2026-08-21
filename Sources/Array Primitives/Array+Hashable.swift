public import Array_Primitive

extension __Array: Hashable where S: Hashable {

    @inlinable
    public func hash(into hasher: inout Hasher) {
        store.hash(into: &hasher)
    }
}
