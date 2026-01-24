struct QueryPlan {
    var with: ComponentManifest = []
    var without: ComponentManifest = []

    consuming func addWith<each T: Component> (
        _ type: repeat (each T).Type
    ) -> Self
    {
        repeat with.append((each T).self)
        return self
    }

    consuming func addWithOut<each T: Component> (
        _ type: repeat (each T).Type
    ) -> Self
    {
        repeat without.append((each T).self)
        return self
    }
}
