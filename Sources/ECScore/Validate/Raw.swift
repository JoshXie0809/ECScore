struct Raw<T> {
    var value: T

    mutating func alter(_ fn: ((inout T) -> Void)) {
        fn(&self.value)
    }

    consuming func upgrade<F: Flags>(_ flagType: F.Type) -> Validated<T, Proof_Init, F> {
        Validated(value: value)
    }
}

struct Validated<T, P: Proof, F: Flags> where F.BaseValue == T {
    let value: T
    var flags = F()

    // 限制只能在檔案內或模組內初始化
    fileprivate init(value: T) {
        self.value = value
    }

    consuming func downgrade() -> Raw<T> {
        Raw(value: value)
    }
}

protocol Proof {}
enum Proof_Init: Proof {}

protocol Flags: OptionSet {
    associatedtype BaseValue
    static func validator(_ at: Int) -> ((_: BaseValue, _: inout Self) -> Bool)?
    static func requirement(for proof: any Proof.Type) -> Self
}


@discardableResult
func validate<T, P: Proof, F: Flags>(
    validated: inout Validated<T, P, F>,
    _ at: Int
) -> Bool {
    guard let validator = F.validator(at) else { return false }
    return validator(validated.value, &validated.flags)
}


// certify
extension Validated {
    /// 嘗試根據當前的 Flags 認證一個新的 Proof
    /// 如果條件不符合，會回傳 nil (或拋出錯誤)
    consuming func certify<NewP: Proof>(_ target: NewP.Type) -> Validated<T, NewP, F>? {
        let requiredFlags = F.requirement(for: target)
        
        // 檢查當前的旗標是否滿足目標 Proof 的所有要求
        if self.flags.isSuperset(of: requiredFlags) {
            // 由於 init 是 fileprivate，在同一個檔案內我們可以自由轉換型別
            var newValidated = Validated<T, NewP, F>(value: self.value)
            newValidated.flags = self.flags
            return newValidated
        }
        
        return nil
    }
}
