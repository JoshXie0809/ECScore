extension Proxy {
    func asBasePlatform() -> BasePlatform {
        var rawStorages: [AnyPlatformStorage?] = []
        rawStorages.append(contentsOf: repeatElement(nil, count: maxRid))

        return BasePlatform(rawStorages)
    }
}