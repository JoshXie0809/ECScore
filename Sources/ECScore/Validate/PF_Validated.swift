public struct Platform_Facts: Facts {
    public typealias T = BasePlatform
    public typealias Flags = CaseFlags
    public typealias Env = Env_Void

    public private(set) var flags = Flags()

    public static func validator(_ flagCase: FlagCase) -> Rule<Self> {
        var fn: Rule<Self>
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

    public init() {
        self.flags = Flags()
    }

    public static func requirement(for proof: any Proof.Type) -> CaseFlags {
        switch proof {
        case is Proof_Handshake.Type:
            return [.handshake]
        default:
            fatalError("does not contains \(proof) in \(Self.self)")
        }
    }

    public enum FlagCase: Int {
        case handshake = 0
    }

    public struct CaseFlags: OptionSet, @unchecked Sendable {
        public var rawValue: Int
        public static let handshake = Self(rawValue: 1 << FlagCase.handshake.rawValue )
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }
}

public enum Proof_Handshake: Proof {}