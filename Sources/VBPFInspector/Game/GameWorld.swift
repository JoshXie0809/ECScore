import ECScore

typealias VBPF = Validated<BasePlatform, Proof_Handshake, Platform_Facts>
typealias Resource = VBPF

final class GameWorld {
    let base: VBPF = makeBootedPlatform()
    let resources: Resource = makeBootedPlatform()
}

