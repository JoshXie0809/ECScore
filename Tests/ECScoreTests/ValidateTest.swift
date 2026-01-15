import Testing
@testable import ECScore

// test Foo Case
enum Proof_FooVerified: Proof {}
struct FooFlags : Flags {
    var rawValue: Int
    // for validate

    typealias Value = String

    static func validator(_ at: Int) -> ((Value, inout Self) -> Bool)? {
        guard let fooCase = FlagCase(rawValue: at) else {
            return nil
        }
        var fn: (FooFlags.Value, inout FooFlags) -> Bool
        
        switch fooCase {
        case .isFoo :
            fn = { (_ val: Value, flags: inout Self) in
                flags.insert(.foo)
                return true
            }
            
        }

        return fn
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
    static let foo = Self(rawValue: 1 << FlagCase.isFoo.rawValue)
}



@Test func rawToValidatedToRaw() {
    // read from edge
    let raw = Raw(value: "hello world")
    print(raw)

    // first validate system
    var val1 = raw.upgrade(FooFlags.self)
    #expect(val1.flags.isEmpty)

    // init status
    print(val1) // simu do sth

    // validate
    let before = val1.flags
    let ok = validate(validated: &val1, FooFlags.FlagCase.isFoo.rawValue /* rule: isFoo */)

    #expect(ok)
    #expect(val1.flags != before)
    #expect(val1.flags.isSuperset(of: [.foo]))

    // after validator
    print(val1) 

    // certify
    let val1_c = val1.certify(Proof_FooVerified.self)
    #expect(val1_c != nil)

    let _: Validated<String, Proof_FooVerified, FooFlags> = val1_c!
    
    print(val1_c!)
    let raw1 = val1_c!.downgrade()
    print(raw1) 

    var raw2 = Raw(value: "x")
    raw2.alter { val in
        val = "Hello world!"
    }

    var val2 = raw2.upgrade(FooFlags.self)
    #expect(val2.certify(Proof_FooVerified.self) == nil)

    let not_ok = validate(validated: &val2, 2)
    #expect(!not_ok)

}