struct Raw<T> {
    var value: T

    mutating func alter(_ fn: ((inout T) -> Void)) {
        fn(&self.value)
    }

    consuming func upgrade<F: Flags>(_ flagTpye: F.Type) -> Validated<T, Proof_Init, F> {
        Validated(value: value)
    }
}

struct Validated<T, P: Proof, F: Flags> {
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


@discardableResult
func Validator<T, P: Proof, F: Flags> (
    validated: inout Validated<T, P, F>,
    _ at: Int,
) -> Bool
{
    if let validator: (_: T, _: inout F) -> Bool = F.validator(at) {
        return validator(validated.value, &validated.flags)
    }

    return false
}

protocol Proof {}
enum Proof_Init: Proof {}
protocol Flags: OptionSet {
    static func validator<T>(_ at: Int) -> ((_: T, _: inout Self) -> Bool)?
}

// test 
struct FooFlag : Flags {
    var rawValue: Int
    static func validator<T>(_ at: Int) -> ((T, inout Self) -> Bool)? {
        guard let fooCase = FlagCase(rawValue: at) else {
            return nil
        }

        let mask = 1 << (fooCase.rawValue - 1)

        switch fooCase {
        case .isFoo :
            let fn = { (_ val: T, flags: inout Self) in
                flags.rawValue |= mask
                return true
            }
            return fn
        }
    }

    enum FlagCase: Int {
        case isFoo = 1
    }
}

