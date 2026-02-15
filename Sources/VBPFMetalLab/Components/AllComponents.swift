import ECScore
import simd

@FastProxy
struct Position: Component {
    var x: Float = 0.0
    var y: Float = 0.0
}

@FastProxy
struct Velocity: Component {
    var dx: Float = 0.0
    var dy: Float = 0.0
}

struct MainChar: TagComponent {}
