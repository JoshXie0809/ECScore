import Testing
@testable import ECScore

// test Foo Case
struct FooFacts<T> : Facts {
    typealias Value = T
    typealias Flags = FooCaseFlags
    typealias Env = F_Void

    private(set) var flags = Flags()

    static func validator(_ at: Int) -> ((borrowing Self.Value, inout Self, Env) -> Bool)? {
        guard let fooCase = FooFlagCase(rawValue: at) else {
            return nil
        }
        var fn: (Self.Value, inout Self, Env) -> Bool

        switch fooCase {
        case .foo :
            fn = { (_ val: Value, facts: inout Self, _) in
                facts.flags.insert(.foo)
                return true
            }

        case .bar :
            fn = { (_ val: Value, facts: inout Self, _) in
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


@Test("測試 generics 的 facts")
func rawToValidatedToRaw() {
    // read from edge
    let raw = Raw(value: "hello world")

    // first validate system
    var val1 = raw.upgrade(FooFacts.self)
    #expect(val1.facts.flags.isEmpty)

    

    // // validate
    let before = val1.facts.flags
    let ok = validate(validated: &val1, FooFlagCase.foo.rawValue)
    validate(validated: &val1, FooFlagCase.bar.rawValue)

    #expect(ok)
    #expect(val1.facts.flags != before)
    #expect(val1.facts.flags.isSuperset(of: [.foo]))


    // // certify
    let val1_c = val1.certify(Proof_FooVerified.self)
    guard case .success = val1_c else { fatalError() }
    
    // Int
    var raw2 = Raw(value: 123)
    raw2.value = 787878

    let val2 = raw2.upgrade(FooFacts.self)
    let val2_c = val2.certify(Proof_FooVerified.self)

    guard case .failure = val2_c else { fatalError() }

}