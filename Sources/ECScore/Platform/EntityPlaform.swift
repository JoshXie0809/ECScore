protocol Platform_Entitiy: Platform, Component {
    func spawn(_: Int) -> [EntityId]
    func despawn(_: EntityId)
}