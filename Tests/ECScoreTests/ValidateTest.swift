import Testing
@testable import ECScore


@Test func rawToValidatedToRaw() {
    let raw = Raw(value: "hello world")
    print(raw)

    let val1 = raw.upgrade(FooFlag.self)
    print(val1)

    let raw1 = val1.downgrade()
    print(raw1)

}