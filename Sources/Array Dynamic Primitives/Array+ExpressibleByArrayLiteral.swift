public import Array_Primitives_Core

extension Array: ExpressibleByArrayLiteral where Element: Copyable {
    @inlinable
    public init(arrayLiteral elements: Element...) {
        var array = Self(initialCapacity: .init(Cardinal(UInt(elements.count))))
        for element in elements {
            array.append(element)
        }
        self = array
    }
}
