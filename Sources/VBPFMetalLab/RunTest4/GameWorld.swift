import ECScore
import simd

final class GameWorld {
    static let totalParticles = 188
    static let mainCharSpeed = Float(0.02)

    let base = makeBootedPlatform()
    let pToken: TypeToken<Position>
    let vToken: TypeToken<Velocity>
    let mainCharToken: TypeToken<MainChar>

    // Resource
    var mainCharDir = simd_float2()
    var dt: Float = 0.0
    var colorTable: [simd_float3] = (0..<128).map { _ in
        simd_float3(Float.random(in: 0...1), Float.random(in: 0...1), Float.random(in: 0...1))
    }

    static let trailCount = 15 // 想要幾個殘影
    var heroHistory: [simd_float2] = Array(repeating: .zero, count: trailCount)

    // simulate data load from file
    init() {
        self.pToken = interop(base, Position.self)
        self.vToken = interop(base, Velocity.self)
        self.mainCharToken = interop(base, MainChar.self)

        let mcT = (mainCharToken, pToken)
        let particlesT = (pToken, vToken)

        emplace(base, tokens: mcT) { entities, pack in
            var (mcSt, pST) = pack.storages
            let e = entities.createEntity()

            mcSt.addComponent(e)
            pST.addComponent(e, Position(x: 0.0, y: 0.0))
        }

        // other particles
        emplace(base, tokens: particlesT) { entities, pack in
            var (pST, vST) = pack.storages
            for _ in 0..<Self.totalParticles {
                let e = entities.createEntity()
                pST.addComponent(e, Position(
                    x: .random(in: -1...1),
                    y: .random(in: -1...1))
                )
                
                var dx = Float.random(in: -0.005...0.005)
                dx = abs(dx) < 0.001 ? copysign(0.001, dx) : dx
                
                var dy = Float.random(in: -0.005...0.005)
                dy = abs(dy) < 0.001 ? copysign(0.001, dy) : dy
                
                vST.addComponent(e, Velocity(
                    dx: dx,
                    dy: dy)
                )
            }
        }

    }


    func updateParticelColor() {
        for i in 0..<128 {
            colorTable[i].x = max(0, min(1, colorTable[i].x + Float.random(in: -0.025...0.025)))
            colorTable[i].y = max(0, min(1, colorTable[i].y + Float.random(in: -0.025...0.025)))
            colorTable[i].z = max(0, min(1, colorTable[i].z + Float.random(in: -0.025...0.025)))
        }
    }

    // update particles place
    func updateParticles() 
    {
        let safeDT = min(dt, 0.033)        
        view(base: base, with: (pToken, vToken)) 
        { _, pos, vel in
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

    func updateMainCharacter() {
        let safeDT = min(dt, 0.033)
        view(base: base, with: pToken, withTag: mainCharToken) 
        { _, pos in
            let p = pos.fast

            // --- 新增：紀錄歷史紀錄 ---
            // 每次移動前，把舊位置往後推
            heroHistory.removeLast()
            heroHistory.insert(simd_float2(Float(p.x), Float(p.y)), at: 0)


            p.x += mainCharDir.x * Self.mainCharSpeed * safeDT * 60
            p.y += mainCharDir.y * Self.mainCharSpeed * safeDT * 60

            if p.x > 1.0 {
                p.x = 1.0      // 強制拉回邊界
            } else if p.x < -1.0 {
                p.x = -1.0
            }

            if p.y > 1.0 {
                p.y = 1.0
            } else if p.y < -1.0 {
                p.y = -1.0
            }
        }
    }

    // write to metal buffer
    func extractDataParticles(
        posPtr: UnsafeMutablePointer<simd_float2>,
        colPtr: UnsafeMutablePointer<simd_float3>,
        capacity: Int) -> Int 
    {
        var idx = 0
        
        view(base: base, with: pToken, withTag: vToken)
        { iterId, pos in
            
            if idx < capacity {
                posPtr[idx] = simd_float2(Float(pos.fast.x), Float(pos.fast.y))
                // 使用你最愛的位元運算索引
                colPtr[idx] = self.colorTable[Int(iterId.eidId & 127)]
                idx += 1
            } else {
                fatalError("particles number more than expected! @extractDataParticles")
            }
        }
        
        return idx
    }

    func extractDataMainCharacter(
        mainCharPtr: UnsafeMutablePointer<simd_float2>
    ) {
        var idx = 0

        view(base: base, with: pToken, withTag: mainCharToken) 
        { iterId, pos in
            if idx < 1 {
                mainCharPtr[idx] = simd_float2(Float(pos.fast.x), Float(pos.fast.y))
                idx += 1
            } else {
                fatalError("more than 1 main char")
            }

        }

    }

    // GameWorld.swift 增加此方法
    func extractHeroTrail(trailPtr: UnsafeMutablePointer<simd_float2>) {
        // 將 heroHistory 陣列直接拷貝到 Buffer
        for i in 0..<Self.trailCount {
            trailPtr[i] = heroHistory[i]
        }
    }
    
}

