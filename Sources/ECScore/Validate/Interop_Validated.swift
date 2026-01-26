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
            fn = { (_ arr, _ facts, _) in
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
        }
        
        return fn
    }

    static func requirement(for proof: any Proof.Type) -> Flags {
        switch proof {
        case is Proof_Unique.Type:
            return [Flags.unique]
        default:
            return []
        }
    }

    enum FlagCase: Int {
        case unique = 0
    }

    struct CaseFlags: OptionSet {
        var rawValue: Int
        static let unique = CaseFlags(rawValue: 1 << FlagCase.unique.rawValue)
    }

    struct MF_Env: Default {
        let registry: RegistryPlatform?
        static func _default() -> Self {
            return Self(registry: nil)
        }
    }
}

enum Proof_Unique: Proof {}
