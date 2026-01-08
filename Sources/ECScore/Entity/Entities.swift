struct EntityId: Hashable {
    let id: Int
    let version: Int
}

extension EntityId: CustomStringConvertible {
    var description: String {
        "E(id:\(id), v:\(version))"
    }
}

class Entities {
    private var freeList: [Int] = [] // where id can be reused
    private var versions:  [Int] = [] // the version for an id, init is 0
    private var isActive: [UInt64] = []

    private(set) var liveCount: Int = 0

    func spawn(_ n: Int = 1) -> [EntityId] {
        var results: [EntityId] = []
        results.reserveCapacity(n)

        for _ in 0..<n {
            let id: Int
            if let recycledId = freeList.popLast() {
                id = recycledId
            } else {
                id = versions.count
                versions.append(0)
                // 檢查是否需要增加 Bitmask 桶子
                if (id >> 6) >= isActive.count {
                    isActive.append(0)
                }
            }

            // 更新 Bitmask
            isActive[id >> 6] |= (UInt64(1) << (id & 63))
            liveCount += 1
            results.append(EntityId(id: id, version: versions[id]))
        }
        return results
    }

    func despawn(_ entity: EntityId) {
        // 安全檢查：版本號必須相符才能銷毀
        guard isValid(entity) else { return }

        let id = entity.id
        // 增加版本號，使現有的 EntityId 失效
        versions[id] += 1
        // 標記為不活躍
        isActive[id >> 6] &= ~(1 << (id & 63))
        // 回收 ID
        freeList.append(id)
        liveCount -= 1
    }

    func isValid(_ entity: EntityId) -> Bool {
        return entity.id < versions.count && versions[entity.id] == entity.version && 
               (isActive[entity.id >> 6] & (1 << (entity.id & 63)) != 0)
    }

}
