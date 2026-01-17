import Testing
@testable import ECScore

// test Foo Case
struct FooFacts<T> : Facts {

    typealias Value = T
    typealias Flags = FooCaseFlags
    private(set) var flags: Flags

    init() {
        self.flags = Flags()
    }

    static func validator(_ at: Int) -> ((Value, inout Self) -> Bool)? {
        guard let fooCase = FooFlagCase(rawValue: at) else {
            return nil
        }
        var fn: (Self.Value, inout Self) -> Bool

        switch fooCase {
        case .foo :
            fn = { (_ val: Value, facts: inout Self) in
                facts.flags.insert(.foo)
                return true
            }

        case .bar :
            fn = { (_ val: Value, facts: inout Self) in
                facts.flags.insert(.bar)
                return true
            }
        }

        return fn
    }

    // for certify
    static func requirement(for proof: any Proof.Type) -> FooCaseFlags {
        switch proof {
        case is Proof_FooVerified.Type:
            return [.foo, .bar] // 必須擁有 foo 這個位元
        default:
            return []    // 預設不需要任何旗標
        }
    }


}

// lower bit at
enum FooFlagCase: Int {
    case foo = 0
    case bar = 1
}

struct FooCaseFlags: OptionSet {
    var rawValue: Int
    static let foo = FooCaseFlags(rawValue: 1 << FooFlagCase.foo.rawValue)
    static let bar = FooCaseFlags(rawValue: 1 << FooFlagCase.bar.rawValue)
}

enum Proof_FooVerified: Proof {}


@Test func rawToValidatedToRaw() {
    // read from edge
    let raw = Raw(value: "hello world")
    print(raw)

    // first validate system
    var val1 = raw.upgrade(FooFacts.self)
    #expect(val1.facts.flags.isEmpty)

    // // init status
    print(val1) // simu do sth

    // // validate
    let before = val1.facts.flags
    let ok = validate(validated: &val1, FooFlagCase.foo.rawValue /* rule: isFoo */)

    #expect(ok)
    #expect(val1.facts.flags != before)
    #expect(val1.facts.flags.isSuperset(of: [.foo]))

    // // after validator
    print(val1) 

    // // certify
    let val1_c = val1.certify(Proof_FooVerified.self)
    print(val1_c)
    
    
    // #expect(val1_c == .failure)


    // let _: Validated<String, Proof_FooVerified, FooFlags> = val1_c!
    
    // print(val1_c!)
    // let raw1 = val1_c!.downgrade()
    // print(raw1) 

    // var raw2 = Raw(value: "x")
    // raw2.alter { val in
    //     val = "Hello world!"
    // }

    // var val2 = raw2.upgrade(FooFlags.self)
    // #expect(val2.certify(Proof_FooVerified.self) == nil)

    // let not_ok = validate(validated: &val2, 2)
    // #expect(!not_ok)

}