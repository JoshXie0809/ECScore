// // LayerFilter // 512
// struct LF_4096<T> {
//     var lfMask: ContiguousArray<UInt64>
//     var lfValue: ContiguousArray<T?>

//     init() {
//         self.lfMask = []
//         self.lfMask.append(contentsOf: repeatElement(UInt64(0), count: 64)) // 2^6 * 2^6 = 2^12 = 4096
//         self.lfValue = []
//         self.lfValue.append(contentsOf: repeatElement(nil, count: 4096))
//     }
// }

// // contain: 4096 entity
// typealias LF_Layer1<T> = LF_4096<T>
// // contain: 16_777_216 entity
// typealias LF_Layer2<T> = LF_4096<LF_4096<T>>

// typealias ComponetTypeLoggerMask = UInt64
// struct ComponetTypeLogger<T> {
//     var mask: ComponetTypeLoggerMask = 0
//     var lf_layer2 = LF_Layer2<T>()
// }

// extension ComponetTypeLogger {
//     @inlinable
//     @inline(__always)
//     mutating func forEach(_ body: () -> Void) {
//         var maskForLayer2 = mask
//         let lf_layer2_Ptr: UnsafeMutablePointer<LF_4096<T>?> = lf_layer2.lfValue.withUnsafeMutableBufferPointer { return $0.baseAddress! }
//         while maskForLayer2 != 0  {
//             let layer2Idx = maskForLayer2.trailingZeroBitCount
//             var maskForLayer1 = lf_layer2.lfMask[layer2Idx]
//             let lf_layer1_Ptr: UnsafeMutablePointer<T> = lf_layer2_Ptr.pointee?.lfValue
//             while maskForLayer1 != 0 {
//                 let layer1Idx = maskForLayer1.trailingZeroBitCount
//                 var maskForEntity = lf_layer2_Ptr.advanced(by: layer1Idx).pointee!.lfMask // bit will always correct


//                 maskForLayer1 &= (maskForLayer1 - 1)
//             }
//             maskForLayer2 &= (maskForLayer2 - 1)
//         }
//     }
// }