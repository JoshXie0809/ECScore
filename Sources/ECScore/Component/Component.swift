public protocol Component: ~Copyable {
    static func createPFStorage() -> AnyPlatformStorage
    static var typeIdString: String { get }
    static var _hs: TypeStrIdHashed_FNV1A_64 { get } // hashed string of typeIdString
    init()
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

// /// 代理指標協議：約束生成的代理結構必須能透過指標初始化
// public protocol FastProxyPointer {
//     associatedtype T
//     init(ptr: UnsafeMutablePointer<T>)
// }

// /// 極速組件協議：掛上 Macro 的組件會自動遵循此協議
// public protocol FastComponentProtocol: Component {
//     associatedtype ProxyMembers: FastProxyPointer where ProxyMembers.T == Self
// }

// // -------------------------------------------------------------------------
// // ComponentProxy 轉發邏輯
// // -------------------------------------------------------------------------

// @frozen
// @dynamicMemberLookup
// public struct ComponentProxy<T>: @unchecked Sendable {
//     @inline(__always) 
//     public let __unsafe_pointer_not_use: UnsafeMutablePointer<T>

//     @inline(__always)
//     public init(pointer: UnsafeMutablePointer<T>) {
//         self.__unsafe_pointer_not_use = pointer
//     }

//     // 路徑 A：極速路徑 (全自動)
//     // 當 T 符合 FastComponentProtocol 時，編譯器優先選擇這個具備具體 Proxy 型別的下標
//     @inline(__always)
//     public subscript<V>(dynamicMember keyPath: WritableKeyPath<T.ProxyMembers, V>) -> V where T: FastComponentProtocol {
//         @inline(__always) _read {
//             yield T.ProxyMembers(ptr: __unsafe_pointer_not_use)[keyPath: keyPath]
//         }
//         @inline(__always) nonmutating _modify {
//             var fast = T.ProxyMembers(ptr: __unsafe_pointer_not_use)
//             yield &fast[keyPath: keyPath]
//         }
//     }

//     // 路徑 B：通用路徑 (備援)
//     @_disfavoredOverload
//     @inline(__always)
//     public subscript<V>(dynamicMember keyPath: WritableKeyPath<T, V>) -> V {
//         @inline(__always) _read { yield __unsafe_pointer_not_use.pointee[keyPath: keyPath] }
//         @inline(__always) nonmutating _modify { yield &__unsafe_pointer_not_use.pointee[keyPath: keyPath] }
//     }
// }


public protocol FastProxyPointer {
    associatedtype T
    init(ptr: UnsafeMutablePointer<T>)
}

/// 極速組件協議：掛上 @FastProxy 的組件會自動遵循此協議
public protocol FastComponentProtocol: Component {
    // 約束組件內部必須有一個叫 ProxyMembers 的結構，且它能操作組件自己
    associatedtype ProxyMembers: FastProxyPointer where ProxyMembers.T == Self
}



// -------------------------------------------------------------------------
// 2. ComponentProxy 實作
// -------------------------------------------------------------------------
@frozen
@dynamicMemberLookup
public struct ComponentProxy<T>: @unchecked Sendable {
    
    // 公開指標供內部/Macro使用 (不建議用戶直接用)
    @inline(__always)
    private let __unsafe_pointer_not_use: UnsafeMutablePointer<T>

    @inline(__always)
    public init(pointer: UnsafeMutablePointer<T>) {
        self.__unsafe_pointer_not_use = pointer
    }
    
    // (保留原本的 subscript 讓 proxy.x 可用，但走 KeyPath 慢速路徑)
    @_disfavoredOverload
    @inline(__always)
    public subscript<V>(dynamicMember keyPath: WritableKeyPath<T, V>) -> V {
        @inline(__always) _read { yield __unsafe_pointer_not_use.pointee[keyPath: keyPath] }
        @inline(__always) nonmutating _modify { yield &__unsafe_pointer_not_use.pointee[keyPath: keyPath] }
    }
}

// 🔥 5. 關鍵解法：泛型擴充 (The 10ms Magic) 🔥
// 只要 T 遵循 FastComponentProtocol，就自動獲得 .fast 通道
extension ComponentProxy where T: FastComponentProtocol {
    
    /// 極速通道：直接回傳 Macro 生成的優化結構體
    /// 這裡的 T.ProxyMembers 就是 Macro 在 Position 裡生成的 struct
    @inline(__always)
    public var fast: T.ProxyMembers {
        return T.ProxyMembers(ptr: __unsafe_pointer_not_use)
    }
}