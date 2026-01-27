protocol Component: ~Copyable {
    static func createPFStorage() -> AnyPlatformStorage
    static var typeIdString: String { get }
    static var _hs: TypeStrIdHashed_FNV1A_64 { get } // hashed string of typeIdString
}

typealias TypeStrIdHashed_FNV1A_64 = UInt64

extension Component {
    static var typeIdString: String {
        String(reflecting: Self.self)
    }

    static var _hs: TypeStrIdHashed_FNV1A_64 {
        typeIdString._hs_fnv1a_64
    }

    static func createPFStorage() -> AnyPlatformStorage {
        PFStorageBox(PFStorageHandle<Self>())
    }
}

extension String {
    var _hs_fnv1a_64: TypeStrIdHashed_FNV1A_64 {
        fnv1a_64(self)
    }
}

@inline(__always)
func fnv1a_64(_ string: borrowing String) -> TypeStrIdHashed_FNV1A_64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in string.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x100000001b3 // 使用 &* 防止溢位檢查
    }
    return hash
}

