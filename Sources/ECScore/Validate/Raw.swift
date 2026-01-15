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

protocol Proof {}
enum Proof_Init: Proof {}
protocol Flags: OptionSet {}

struct FooFlag : Flags {
    var rawValue: Int
    static let isFoo = FooFlag(rawValue: 1 << 0)
}

