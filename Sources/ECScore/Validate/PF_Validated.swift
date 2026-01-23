struct Platform_Facts: Facts {
    typealias Value = BasePlatform
    typealias Flags = CaseFlags
    private(set) var flags = Flags()

    static func validator(_ at: Int) -> ((Self.Value, inout Self) -> Bool)? {
        guard let flagCase = FlagCase(rawValue: at) else {
            return nil
        }

        var fn: (Self.Value, inout Self) -> Bool

        switch flagCase {
        case .handshake: 
            fn = { (_ pf, _ facts) in
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

extension Validated<BasePlatform, Proof_Handshake, Platform_Facts> {
    @inlinable
    var registry: any Platform_Registry {
        value.storages[0]!.get(EntityId(id: 0, version: 0)) as! Platform_Registry
    }
    
    @inlinable
    var entities: any Platform_Entity {
        value.storages[1]!.get(EntityId(id: 0, version: 0)) as! Platform_Entity
    }

    @inlinable
    var storages: [AnyPlatformStorage?] {
        value.storages
    }
}