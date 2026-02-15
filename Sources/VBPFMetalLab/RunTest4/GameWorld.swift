import ECScore
import simd

final class GameWorld {
    static let totalParticle = 1_000

    let base = makeBootedPlatform()
    let pToken: TypeToken<Position>
    let vToken: TypeToken<Velocity>

    // simulate data load from file
    init() {
        self.pToken = interop(base, Position.self)
        self.vToken = interop(base, Velocity.self)

        let mcT = (pToken, vToken)
        emplace(base, tokens: mcT) { entities, pack in
            var (pST, vST) = pack.storages
            for _ in 0..<Self.total {
                let e = entities.createEntity()
                pST.addComponent(e, Position(x: .random(in: -1...1), y: .random(in: -1...1)))
                vST.addComponent(e, Velocity(dx: .random(in: -0.005...0.005), dy: .random(in: -0.005...0.005)))
            }
        }
    }

}