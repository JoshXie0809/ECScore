struct Raw<T>: ~Copyable {
    var value: T

    init(value: consuming T) {
        self.value = value
    }

    mutating func alter(_ fn: ((inout T) -> Void)) {
        fn(&self.value)
    }

    consuming func upgrade<F: Facts>(_ flagType: F.Type) -> Validated<T, Proof_Init, F> 
        where T == F.Value
    {
        Validated(value: value)
    }

    consuming func downgrade() -> T {
        return value
    }
}

struct Validated<T, P: Proof, F: Facts>: ~Copyable where F.Value == T {
    let value: T
    fileprivate var facts: F
    fileprivate init(value: T, facts: F = F()) {
        self.value = value
        self.facts = facts
    }

    consuming func downgrade() -> Raw<T> {
        Raw(value: value)
    }
}

protocol Proof {}
enum Proof_Init: Proof {}
typealias Rule<F: Facts> = ((_: borrowing F.T, _: inout F,  _: borrowing F.Env) -> Bool)

protocol Facts<T> {
    associatedtype T
    associatedtype Flags: OptionSet
    associatedtype FlagCase
    associatedtype Env: Default
    typealias Value = T

    var flags: Flags { get }
    init()
    static func validator(_ : FlagCase) -> Rule<Self>
    static func requirement(for proof: any Proof.Type) -> Flags
}

protocol Default {
    static func _default() -> Self
}

struct Env_Void {}
extension Env_Void: Default {
    static func _default() -> Self { Self() }
}

@discardableResult
func validate<T, P: Proof, F: Facts>(
    validated: inout Validated<T, P, F>,
    other_validated_resource: borrowing F.Env = F.Env._default(),
    _ flagCase : F.FlagCase,
) -> Bool {
    let validator: Rule<F> = F.validator(flagCase)
    return validator(validated.value, &validated.facts, other_validated_resource)
}

// certify
extension Validated {
    consuming func certify<NewP: Proof>(_ target: NewP.Type) 
    -> CertifyResult<T, NewP, F>
    {
        let requiredFlags = F.requirement(for: target)
        if self.facts.flags.isSuperset(of: requiredFlags) {
            return .success(Validated<T, NewP, F>(value: self.value, facts: self.facts))
        }
        
        // 這裡不再回傳 nil，而是誠實回報缺了什麼
        let missing = requiredFlags.subtracting(self.facts.flags)
        return .failure(missingFlags: missing, proofName: "\(target)")
    }
}

enum CertifyResult <T, P: Proof, F: Facts>: ~Copyable where T == F.Value {
    case success(Validated<T, P, F>)
    case failure(missingFlags: F.Flags, proofName: String)
}

// clone
extension Validated {
    borrowing func clone() -> Validated<T, P, F> {
        return Validated<T, P, F>(value: self.value, facts: self.facts)    
    }
}

extension Validated {
    var flags: F.Flags {
        facts.flags
    }
}
