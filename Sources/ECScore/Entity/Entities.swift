public struct EntityId: Hashable, Comparable, Sendable {
    public let id: Int
    public let version: Int

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.id < rhs.id
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id && lhs.version == rhs.version
    }

    public init(id: Int, version: Int) {
        self.id = id
        self.version = version
    }
}

extension EntityId: CustomStringConvertible {
    public var description: String {
        "E(id:\(id), v:\(version))"
    }
}

public class Entities {
    @inline(__always)
    private var freeList: [Int] = [] // where id can be reused
    @inline(__always)
    private var versions:  [Int] = [] // the version for an id, init is 0
    @inline(__always)
    private var isActive: [UInt64] = []
    @inline(__always)
    var maxId : Int {
        versions.count - 1
    }

    @usableFromInline
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
                // 檢查是否需要增加 Bitmask bucket
                if (id >> 6) >= isActive.count {
                    isActive.append(0)
                }
            }

            // 更新 Bitmask
            isActive[id >> 6] |= (UInt64(1) << (id & 63))
            results.append(EntityId(id: id, version: versions[id]))
        }
        return results
    }

    @usableFromInline
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
    }

    @usableFromInline
    func isValid(_ entity: EntityId) -> Bool {
        return entity.id < versions.count && versions[entity.id] == entity.version && 
               (isActive[entity.id >> 6] & (1 << (entity.id & 63)) != 0)
    }

    @usableFromInline
    func idIsActive(_ id: Int) -> Bool {
        return id <= maxId && (isActive[id >> 6] & (1 << (id & 63)) != 0)
    }

    @usableFromInline
    func getVersion(_ id: Int) -> Int {
        return versions[id]
    }

    @usableFromInline
    func getActiveEntitiesMask_Uncheck(_ block: Int) -> UInt64 {
        isActive[block]
    } 
}
