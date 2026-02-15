import ECScore
import simd

final class GameWorld {
    static let totalParticles = 168

    let base = makeBootedPlatform()
    let pToken: TypeToken<Position>
    let vToken: TypeToken<Velocity>
    
    var colorTable: [simd_float3] = (0..<128).map { _ in
        simd_float3(Float.random(in: 0...1), Float.random(in: 0...1), Float.random(in: 0...1))
    }

    // simulate data load from file
    init() {
        self.pToken = interop(base, Position.self)
        self.vToken = interop(base, Velocity.self)

        let mcT = (pToken, vToken)
        emplace(base, tokens: mcT) { entities, pack in
            var (pST, vST) = pack.storages
            for _ in 0..<Self.totalParticles {
                let e = entities.createEntity()
                pST.addComponent(e, Position(x: .random(in: -1...1), y: .random(in: -1...1)))
                vST.addComponent(e, Velocity(dx: .random(in: -0.005...0.005), dy: .random(in: -0.005...0.005)))
            }
        }
    }

    // update particles place
    func update(dt: Float) {
        let safeDT = min(dt, 0.033)
        
        for i in 0..<128 {
            colorTable[i].x = max(0, min(1, colorTable[i].x + Float.random(in: -0.1...0.1)))
            colorTable[i].y = max(0, min(1, colorTable[i].y + Float.random(in: -0.1...0.1)))
            colorTable[i].z = max(0, min(1, colorTable[i].z + Float.random(in: -0.1...0.1)))
        }
        
        view(base: base, with: (pToken, vToken)) { _, pos, vel in
            let p = pos.fast
            let v = vel.fast

            p.x += v.dx * safeDT * 60.0
            p.y += v.dy * safeDT * 60.0

            if p.x > 1.0 {
                p.x = 1.0      // 強制拉回邊界
                v.dx *= -1     // 反轉速度
            } else if p.x < -1.0 {
                p.x = -1.0
                v.dx *= -1
            }

            if p.y > 1.0 {
                p.y = 1.0
                v.dy *= -1
            } else if p.y < -1.0 {
                p.y = -1.0
                v.dy *= -1
            }
        }
    }

    // write to metal buffer
    func extractData(posPtr: UnsafeMutablePointer<simd_float2>,
                     colPtr: UnsafeMutablePointer<simd_float3>,
                     capacity: Int) -> Int {
        var idx = 0
        
        view(base: base, with: pToken, withTag: vToken)
        { iterId, pos in
            
            if idx < capacity {
                posPtr[idx] = simd_float2(Float(pos.fast.x), Float(pos.fast.y))
                // 使用你最愛的位元運算索引
                colPtr[idx] = self.colorTable[Int(iterId.eidId & 127)]
                idx += 1
            }
        }
        
        return idx
    }

}
