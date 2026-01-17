struct Manifest_Facts: Facts 
{
    typealias Value = ComponentManifest
    typealias Flags = CaseFlags
    private(set) var flags: Flags

    init() {
        self.flags = Flags()
    }

    static func validator(_ at: Int) -> ((Self.Value, inout Self) -> Bool)? {
        guard let PFCase = FlagCase(rawValue: at) else {
            return nil
        }

        var fn: (Self.Value, inout Self) -> Bool

        switch PFCase {
        case .unique: 
            fn = { (_ arr, _ mask) in
                var seen = Set<ObjectIdentifier>()
                for type in arr {
                    let type_id = ObjectIdentifier(type)
                    if(seen.contains(type_id)) { return false }
                    seen.insert(type_id)
                }

                // pf can handshake
                mask.flags.insert([.unique])
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
}




enum Proof_Unique: Proof {}