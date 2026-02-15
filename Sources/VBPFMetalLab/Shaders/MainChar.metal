#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float3 color;
    float2 uv;
};

// ---【 主角 MainChar 區 】---
vertex VertexOut hero_vertex(
    uint vid [[vertex_id]],
    constant float2 *pos [[buffer(0)]], // 主角只有一顆，不需 iid
    constant float3 *col [[buffer(1)]]
) {
    float size = 0.08; // 主角特別大
    float2 quad[4] = { float2(-size, -size), float2(size, -size), float2(-size,  size), float2(size,  size) };

    VertexOut out;
    out.position = float4(quad[vid] + pos[0], 0, 1); // 直接拿第 0 個
    out.color = col[0];
    out.uv = quad[vid] * (1.0 / size);
    return out;
}

fragment float4 hero_fragment(
    VertexOut in [[stage_in]],
    constant float &time [[buffer(0)]] // 接收來自 Swift 的時間
) {
    float dist = length(in.uv);
    
    // 1. 呼吸效果 (低頻正弦波，周期約 3 秒)
    // 讓數值在 0.8 到 1.2 之間縮放
    float breathe = 1.0 + 0.2 * sin(time * 2.0);
    
    // 2. 閃爍效果 (高頻隨機感)
    // 利用 fract 與 sin 產生簡單的噪聲
    float flicker = 0.95 + 0.05 * fract(sin(time * 60.0) * 43758.5453);
    
    // 3. 混合光暈
    // 讓邊界更柔和，且隨呼吸改變範圍
    float alpha = 0.45 - smoothstep(0.3 * breathe, 0.5 * breathe, dist);
    
    // 4. 計算最終發光強度
    // 呼吸影響光暈大小，閃爍影響光暈亮度
    float glow = exp(-dist * (3.0 / breathe)) * 0.7 * flicker;
    
    // 主角呈現：白色中心 + 呼吸光暈
    float3 finalColor = in.color + glow;
    float finalAlpha = (alpha + glow) * flicker;
    
    return float4(finalColor, finalAlpha);
}
