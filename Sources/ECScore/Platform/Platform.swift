public protocol Platform {}

public protocol AnyPlatformStorage {
    mutating func remove(eid: EntityId)
    mutating func rawAdd(eid: EntityId, component: Any)

    func getWithDenseIndex_Uncheck(_ index: Int) -> Any?
    func get(_ eid: EntityId) -> Any?

    var storageType: any Component.Type { get }
    var activeEntityCount: Int {get}
}
