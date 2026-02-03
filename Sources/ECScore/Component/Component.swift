public protocol Component: ~Copyable {
    static func createPFStorage() -> AnyPlatformStorage
    static var typeIdString: String { get }
    static var _hs: TypeStrIdHashed_FNV1A_64 { get } // hashed string of typeIdString
}

public typealias TypeStrIdHashed_FNV1A_64 = UInt64

extension Component {
    public static var typeIdString: String {
        String(reflecting: Self.self)
    }

    public static var _hs: TypeStrIdHashed_FNV1A_64 {
        typeIdString._hs_fnv1a_64
    }

    public static func createPFStorage() -> AnyPlatformStorage {
        PFStorageBox(PFStorageHandle<Self>())
    }
}

extension String {
    public var _hs_fnv1a_64: TypeStrIdHashed_FNV1A_64 {
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

/// 代理指標協議：約束生成的代理結構必須能透過指標初始化
public protocol FastProxyPointer {
    associatedtype T
    init(ptr: UnsafeMutablePointer<T>)
}

/// 極速組件協議：掛上 Macro 的組件會自動遵循此協議
public protocol FastComponentProtocol: Component {
    associatedtype ProxyMembers: FastProxyPointer where ProxyMembers.T == Self
}

// -------------------------------------------------------------------------
// ComponentProxy 轉發邏輯
// -------------------------------------------------------------------------

@frozen
@dynamicMemberLookup
public struct ComponentProxy<T> {
    private let pointer: UnsafeMutablePointer<T>

    @inline(__always)
    public init(pointer: UnsafeMutablePointer<T>) {
        self.pointer = pointer
    }

    // 路徑 A：極速路徑 (全自動)
    // 當 T 符合 FastComponentProtocol 時，編譯器優先選擇這個具備具體 Proxy 型別的下標
    @inline(__always)
    public subscript<V>(dynamicMember keyPath: WritableKeyPath<T.ProxyMembers, V>) -> V where T: FastComponentProtocol {
        @inline(__always) _read {
            yield T.ProxyMembers(ptr: pointer)[keyPath: keyPath]
        }
        @inline(__always) nonmutating _modify {
            var fast = T.ProxyMembers(ptr: pointer)
            yield &fast[keyPath: keyPath]
        }
    }

    // 路徑 B：通用路徑 (備援)
    @_disfavoredOverload
    @inline(__always)
    public subscript<V>(dynamicMember keyPath: WritableKeyPath<T, V>) -> V {
        @inline(__always) _read { yield pointer.pointee[keyPath: keyPath] }
        @inline(__always) nonmutating _modify { yield &pointer.pointee[keyPath: keyPath] }
    }
}
