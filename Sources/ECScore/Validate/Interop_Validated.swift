struct Manifest_Facts: Facts 
{
    typealias Value = ComponentManifest
    typealias Flags = CaseFlags
    typealias Env = MF_Env

    private(set) var flags: Flags
    init() {
        self.flags = Flags()
    }

    static func validator(_ at: Int) -> ((borrowing Self.Value, inout Self, Env) -> Bool)? {
        guard let flagCase = FlagCase(rawValue: at) else {
            return nil
        }

        var fn: (borrowing Self.Value, inout Self, Env) -> Bool

        switch flagCase {
        case .unique: 
            fn = { (arr, facts, _) in
                var seen = Set<ObjectIdentifier>()
                for type in arr {
                    let type_id = ObjectIdentifier(type)
                    if(seen.contains(type_id)) { return false }
                    seen.insert(type_id)
                }

                // pf can handshake
                facts.flags.insert([.unique])
                return true
            }

        case .noTypeStringCollisoin: 
            fn = { (arr, facts, env) in
                guard let register = env.registry else { return false }
                var localNames = [String: any Component.Type]()
                
                for type in arr {
                    let name = String(reflecting: type) // 取得型別名稱
                    
                    // A. 檢查是否與 Registry 內已有的資料碰撞
                    if let rid = register.lookup(type._hs) {
                        let storedType = register.lookup(rid)!
                        if storedType != type { return false }
                    }
                    
                    // B. 檢查這批 Manifest 內部是否自相矛盾
                    if let firstType = localNames[name] {
                        if firstType != type { return false }
                    }
                    
                    localNames[name] = type
                }
                
                facts.flags.insert([.noTypeStringCollisoin])
                return true
            }
        }
        
        return fn
    }

    static func requirement(for proof: any Proof.Type) -> Flags {
        switch proof {
        case is Proof_Ok_Manifest.Type:
            return [Flags.unique, Flags.noTypeStringCollisoin]
        default:
            return []
        }
    }

    enum FlagCase: Int {
        case unique = 0
        case noTypeStringCollisoin = 1
    }

    struct CaseFlags: OptionSet {
        var rawValue: Int
        static let unique = Flags(rawValue: 1 << FlagCase.unique.rawValue)
        static let noTypeStringCollisoin = Flags(rawValue: 1 << FlagCase.noTypeStringCollisoin.rawValue)
    }

    struct MF_Env: Default {
        var registry: Platform_Registry?
        static func _default() -> Self {
            return Self(registry: nil)
        }
    }
}

enum Proof_Ok_Manifest: Proof {}
