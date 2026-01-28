struct QueryPlanFacts: Facts {
    typealias T = QueryPlan
    typealias Flags = CaseFlags
    typealias Env = Env_Void
    
    private(set) var flags = Flags()

    static func validator(_ flagCase: FlagCase) -> Rule<Self> {
        var fn: (borrowing Self.Value, inout Self, Env) -> Bool

        switch flagCase {
        case .include_list_unique:
            fn = { (_ qp, _ facts, _) in
                return Self.unique(arr: qp.with, flags: &facts.flags, caseFlag: .include_list_unique)
            }
        
        case .exclude_list_unique:
            fn = { (_ qp, _ facts, _) in
                return Self.unique(arr: qp.without, flags: &facts.flags, caseFlag: .exclude_list_unique)
            }

        case .both_list_merged_unique:
            fn = { (_ qp, _ facts, _) in
                return Self.unique2(arr1: qp.with, arr2: qp.without, flags: &facts.flags, caseFlag: .both_list_merged_unique)
            }
        }
        return fn
    }

    static func requirement(for proof: any Proof.Type) -> CaseFlags {
        switch proof {
        case is Proof_ValidQueryPlan.Type:
            return [.exclude_list_unique, .include_list_unique, .both_list_merged_unique]
        default:
            fatalError("does not contains \(proof) in \(Self.self)")
        }
    }

    enum FlagCase: Int {
        case include_list_unique = 0
        case exclude_list_unique = 1
        case both_list_merged_unique = 2
    }

    struct CaseFlags: OptionSet {
        var rawValue: Int
        static let include_list_unique = Self(rawValue: 1 << FlagCase.include_list_unique.rawValue )
        static let exclude_list_unique = Self(rawValue: 1 << FlagCase.exclude_list_unique.rawValue )
        static let both_list_merged_unique = Self(rawValue: 1 << FlagCase.both_list_merged_unique.rawValue )
    }

    private static func unique(arr: borrowing ComponentManifest, flags: inout CaseFlags, caseFlag: CaseFlags) -> Bool 
    {
        var seen = Set<ObjectIdentifier>()
        var result = true

        Self.unique_helper(arr: arr, result: &result, seen: &seen)
        if(result == false) { return false }
        
        // unique
        flags.insert(caseFlag)
        return true
    }

    private static func unique2(arr1: borrowing ComponentManifest, arr2: borrowing ComponentManifest, flags: inout CaseFlags, caseFlag: CaseFlags) -> Bool 
    {
        var seen = Set<ObjectIdentifier>()
        var result = true

        Self.unique_helper(arr: arr1, result: &result, seen: &seen)
        if(result == false) { return false }

        Self.unique_helper(arr: arr2, result: &result, seen: &seen)
        if(result == false) { return false }
        
        // unique
        flags.insert(caseFlag)
        return true
    }
    
    @inline(__always)
    private static func unique_helper(
        arr: borrowing ComponentManifest, 
        result: inout Bool, 
        seen: inout Set<ObjectIdentifier>
    ) {
        for i in 0..<arr.count {
            let type_id = ObjectIdentifier(arr[i])
            if !seen.insert(type_id).inserted { result = false; return }
        }
    }
    
}

enum Proof_ValidQueryPlan: Proof {}
