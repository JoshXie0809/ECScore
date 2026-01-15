import Testing
@testable import ECScore

// test Foo Case
enum Proof_FooVerified: Proof {}
struct FooFlag : Flags {
    var rawValue: Int
    // for validate
    static func validator<T>(_ at: Int) -> ((T, inout Self) -> Bool)? {
        guard let fooCase = FlagCase(rawValue: at) else {
            return nil
        }

        let mask = 1 << fooCase.rawValue

        switch fooCase {
        case .isFoo :
            let fn = { (_ val: T, flags: inout Self) in
                flags.rawValue |= mask
                return true
            }
            return fn
        }
    }

    // for certify
    static func requirement(for proof: any Proof.Type) -> Self {
        switch proof {
        case is Proof_FooVerified.Type:
            return [.foo] // 必須擁有 foo 這個位元
        default:
            return []    // 預設不需要任何旗標
        }
    }

    // lower bit at
    enum FlagCase: Int {
        case isFoo = 0
    }

    // 建議定義靜態屬性方便讀取
    static let foo = FooFlag(rawValue: 1 << FlagCase.isFoo.rawValue)
}



@Test func rawToValidatedToRaw() {
    // read from edge
    let raw = Raw(value: "hello world")
    print(raw)

    // first validate system
    var val1 = raw.upgrade(FooFlag.self)
    #expect(val1.flags.isEmpty)

    // init status
    print(val1) // simu do sth

    // validate
    let before = val1.flags
    let ok = validate(validated: &val1, FooFlag.FlagCase.isFoo.rawValue /* rule: isFoo */)

    #expect(ok)
    #expect(val1.flags != before)
    #expect(val1.flags.isSuperset(of: [.foo]))

    // after validator
    print(val1) 

    // certify
    let val1_c = val1.certify(Proof_FooVerified.self)
    #expect(val1_c != nil)

    let _: Validated<String, Proof_FooVerified, FooFlag> = val1_c!
    
    print(val1_c!)
    let raw1 = val1_c!.downgrade()
    print(raw1) 

    let raw2 = Raw(value: "x")
    let val2 = raw2.upgrade(FooFlag.self)
    #expect(val2.certify(Proof_FooVerified.self) == nil)


}