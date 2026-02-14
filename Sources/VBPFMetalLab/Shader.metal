#include <metal_stdlib>
using namespace metal;

struct AddParams {
    uint count;
};

kernel void add_arrays(
    const device float* inA [[buffer(0)]],
    const device float* inB [[buffer(1)]],
    device float* outC [[buffer(2)]],
    constant AddParams& params [[buffer(3)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= params.count) { return; }
    outC[gid] = inA[gid] + inB[gid];
}
