public protocol TagComponent: Component {}

public extension TagComponent {
    static func createSparseSet() -> any AnySparseSet {
        SparseSet_L2_2_Tag<Self>()
    }
}