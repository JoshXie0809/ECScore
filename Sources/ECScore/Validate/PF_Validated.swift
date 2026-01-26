struct Platform_Facts: Facts {
    typealias Value = BasePlatform
    typealias Flags = CaseFlags
    typealias Env = Env_Void

    private(set) var flags = Flags()

    static func validator(_ at: Int) -> ((borrowing Self.Value, inout Self, borrowing Env) -> Bool)? {
        guard let flagCase = FlagCase(rawValue: at) else {
            return nil
        }

        var fn: (borrowing Self.Value, inout Self, borrowing Env) -> Bool

        switch flagCase {
        case .handshake: 
            fn = { (_ pf, _ facts, _) in
                guard pf.registry != nil else { return false }
                guard pf.entities != nil else { return false }
                // pf can handshake
                facts.flags.insert([.handshake])
                return true
            }
        }
        
        return fn
    }

    static func requirement(for proof: any Proof.Type) -> CaseFlags {
        switch proof {
        case is Proof_Handshake.Type:
            return [.handshake]
        default:
            return []
        }
    }

    enum FlagCase: Int {
        case handshake = 0
    }

    struct CaseFlags: OptionSet {
        var rawValue: Int
        static let handshake = Self(rawValue: 1 << FlagCase.handshake.rawValue )
    }
}

enum Proof_Handshake: Proof {}