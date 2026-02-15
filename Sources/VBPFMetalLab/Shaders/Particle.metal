#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float3 color;
    float2 uv;
};

vertex VertexOut vertex_main(
    uint vid [[vertex_id]],
    uint iid [[instance_id]],
    constant float2 *allPos    [[buffer(0)]],
    constant float3 *allColors [[buffer(1)]]
) {
    float size = 0.025;

    float2 quad[4] = {
        float2(-size, -size),
        float2(size, -size),
        float2(-size,  size),
        float2(size,  size)
    };

    VertexOut out;
    out.position = float4(quad[vid] + allPos[iid], 0, 1);
    out.color = allColors[iid];
    out.uv = quad[vid] * (1.0 / size);

    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    float dist = length(in.uv);
    float alpha = 1.0 - smoothstep(0.45, 0.5, dist);
    if (alpha <= 0.0) discard_fragment();
    return float4(in.color, alpha);
}
