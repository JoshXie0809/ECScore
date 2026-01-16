struct Manifest_Flags: Flags {
    var rawValue: Int

    typealias Value = ComponentManifest

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
                mask.insert([.unique])
                return true
            }
        }
        
        return fn
    }

    static func requirement(for proof: any Proof.Type) -> Self {
        switch proof {
        case is Proof_Unique.Type:
            return [.unique]
        default:
            return []
        }
    }

    enum FlagCase: Int {
        case unique = 0
    }

    static let unique = Self(rawValue: 1 << FlagCase.unique.rawValue)
}

enum Proof_Unique: Proof {}