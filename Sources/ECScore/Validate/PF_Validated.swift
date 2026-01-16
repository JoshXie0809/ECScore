struct Platform_Flags: Flags {
    var rawValue: Int

    typealias Value = ComponentManifest

    static func validator(_ at: Int) -> ((Self.Value, inout Self) -> Bool)? {
        guard let PFCase = FlagCase(rawValue: at) else {
            return nil
        }

        var fn: (Self.Value, inout Self) -> Bool

        switch PFCase {
        case .noDouble: 
            fn = { (_ arr, _ mask) in
                var seen = Set<ObjectIdentifier>()
                for comp in arr {
                    let (inserted, _) = seen.insert(ObjectIdentifier(comp))
                    guard inserted else { return false }
                }
                // arr is valid
                mask.insert([.noDouble])
                return true
            }
        }
        
        return fn
    }

    static func requirement(for proof: any Proof.Type) -> Platform_Flags {
        switch proof {
        case is Proof_Introp.Type:
            return [.noDouble]
        default:
            return []
        }
    }

    enum FlagCase: Int {
        case noDouble = 0
    }

    static let noDouble = Platform_Flags(rawValue: 1 << FlagCase.noDouble.rawValue)
}

enum Proof_Introp: Proof {}