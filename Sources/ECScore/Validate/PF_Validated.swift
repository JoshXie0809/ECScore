struct Platform_Flags: Flags {
    var rawValue: Int

    typealias Value = BasePlatform

    static func validator(_ at: Int) -> ((Self.Value, inout Self) -> Bool)? {
        guard let PFCase = FlagCase(rawValue: at) else {
            return nil
        }

        var fn: (Self.Value, inout Self) -> Bool

        switch PFCase {
        case .handshake: 
            fn = { (_ pf, _ mask) in
                guard pf.registry != nil else {return false}
                guard pf.entities != nil else {return false}
                // pf can handshake
                mask.insert([.handshake])
                return true
            }
        }
        
        return fn
    }

    static func requirement(for proof: any Proof.Type) -> Platform_Flags {
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

    static let handshake = Platform_Flags(rawValue: 1 << FlagCase.handshake.rawValue)
}

enum Proof_Handshake: Proof {}