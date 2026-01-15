import Testing
@testable import ECScore


@Test func rawToValidatedToRaw() {
    // read from edge
    let raw = Raw(value: "hello world")
    print(raw)

    // first validate system
    var val1 = raw.upgrade(FooFlag.self)
    // init status
    print(val1) // simu do sth

    // validate
    validate(validated: &val1, FooFlag.FlagCase.isFoo.rawValue)
    // after validator
    print(val1) 

    // certify
    let val1_c = val1.certify(Proof_FooVerified.self)
    #expect(val1_c != nil)
    
    print(val1_c!)
    let raw1 = val1_c!.downgrade()
    print(raw1) 

    // // second validate system
    // let val2 = raw.upgrade(Platform_Flags.self)
    // print(val2) // simu do sth

}