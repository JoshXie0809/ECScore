struct Raw<T> {
    var value: T

    mutating func alter(_ fn: ((inout T) -> Void)) {
        fn(&self.value)
    }

    consuming func upgrade<F: Facts>(_ flagType: F.Type) -> Validated<T, Proof_Init, F> 
    where T == F.Value
    {
        Validated(value: value)
    }
}

struct Validated<T, P: Proof, F: Facts> where F.Value == T {
    let value: T
    var facts: F

    // 限制只能在檔案內或模組內初始化
    fileprivate init(value: T) {
        self.value = value
        self.facts = F()
    }

    fileprivate init(value: T, facts: F) {
        self.value = value
        self.facts = facts
    }

    consuming func downgrade() -> Raw<T> {
        Raw(value: value)
    }
}

protocol Proof {}
enum Proof_Init: Proof {}

protocol Facts<T> {
    associatedtype T
    associatedtype Flags: OptionSet
    typealias Value = T
    var flags: Flags { get }

    init()
    static func validator(_ at: Int) -> ((_: Value, _: inout Self) -> Bool)?
    static func requirement(for proof: any Proof.Type) -> Flags
}

@discardableResult
func validate<T, P: Proof, F: Facts>(
    validated: inout Validated<T, P, F>,
    _ at: Int
) -> Bool {
    guard let validator = F.validator(at) else { return false }
    return validator(validated.value, &validated.facts)
}

// certify
extension Validated {
    /// 如果條件不符合，會回傳 nil (或拋出錯誤) 
    /// 會改成 throws Errors 的
    consuming func certify<NewP: Proof>(_ target: NewP.Type) 
    -> CertiftyResult<T, NewP, F>
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

enum CertiftyResult <T, P: Proof, F: Facts> where T == F.Value {
    case success(Validated<T, P, F>)
    case failure(missingFlags: F.Flags, proofName: String)
}