import Testing
@testable import ECScore

// test Foo Case
struct FooFacts<T> : Facts {
    typealias Flags = FooCaseFlags
    typealias FlagCase = FooFlagCase
    typealias Env = Env_Void

    private(set) var flags = Flags()

    static func validator(_ flagCase: FlagCase) -> Rule<Self> {
        var fn: (Self.Value, inout Self, Env) -> Bool

        switch flagCase {
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
    #expect(val1.flags.isEmpty)

    // // validate
    let before = val1.flags
    let ok = validate(validated: &val1, .foo)
    validate(validated: &val1, .bar)

    #expect(ok)
    #expect(val1.flags != before)
    #expect(val1.flags.isSuperset(of: [.foo]))


    // // certify
    let val1_c = val1.certify(Proof_FooVerified.self)
    guard case .success = val1_c else { fatalError() }
    
    // Int
    var raw2 = Raw(value: 123)
    raw2.alter { val in  val = 23435435}

    let val2 = raw2.upgrade(FooFacts.self)
    let val2_c = val2.certify(Proof_FooVerified.self)

    guard case .failure = val2_c else { fatalError() }

}