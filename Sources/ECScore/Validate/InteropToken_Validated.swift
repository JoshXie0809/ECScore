struct InteropToken_Facts: Facts {
    typealias Value = InteropToken
    typealias Flags = CaseFlags
    private(set) var flags = Flags()

    static func validator(_ at: Int) -> ((Value, inout InteropToken_Facts) -> Bool)? {
        guard let itCase = FlagCase(rawValue: at) else {
            return nil
        }
        var fn: (Self.Value, inout Self) -> Bool

        switch itCase {
        case .noRegistryPF: 
            fn = { (_ value, _ facts) in
                if value.ridToAt[0] == nil { // rid.id = 0 is registry platform
                    return true
                }
                return false
            }

        case .hasEntityPF: 
            fn = { (_ value, _ facts) in
                if value.ridToAt[1] != nil { // rid.id = 1 is entities platform
                    return true
                }
                return false
            }
        }

        return fn
    }

    static func requirement(for proof: any Proof.Type) -> CaseFlags {
        switch proof {
        case is Proof_SubPlatform.Type:
            return [.noRegistryPF, .hasEntityPF]
        default:
            return []
        }
    }



    enum FlagCase: Int {
        case noRegistryPF = 0
        case hasEntityPF = 1
    }

    struct CaseFlags: OptionSet {
        var rawValue: Int
        static let noRegistryPF = Self(rawValue: 1 << FlagCase.noRegistryPF.rawValue )
        static let hasEntityPF = Self(rawValue: 1 << FlagCase.hasEntityPF.rawValue )
    }

}

enum Proof_SubPlatform: Proof {}