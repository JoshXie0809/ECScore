#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float3 color;
    float2 uv;
    float trailAlpha; // 👈 關鍵修正：補上這個屬性，解決後續編譯連鎖錯誤
};

// ---【 主角 MainChar 區 】---
vertex VertexOut hero_vertex(
    uint vid [[vertex_id]],
    uint iid [[instance_id]], // 用於區分本體與殘影
    constant float2 *pos [[buffer(0)]], // 接收 heroHistory 陣列
    constant float3 *col [[buffer(1)]]
) {
    // 殘影邏輯：iid 越大代表越舊，尺寸稍微縮小
    float size = (iid == 0) ? 0.05 : (0.045 * (1.0 - float(iid)/15.0));
    
    // 關鍵修正：使用 pos[iid] 取得對應的歷史位置
    float2 center = pos[iid];
    float2 quad[4] = {
        float2(-size, -size), float2(size, -size),
        float2(-size,  size), float2(size,  size)
    };

    VertexOut out;
    // 關鍵修正：將頂點位移套用到正確的歷史中心點
    out.position = float4(quad[vid] + center, 0, 1);
    out.color = col[0];
    out.uv = quad[vid] * (1.0 / size);
    
    // 計算殘影衰減：iid 0 是 1.0 (本體)，iid 14 則接近透明
    out.trailAlpha = 1.0 - (float(iid) / 20.0);
    
    return out;
}

fragment float4 hero_fragment(
    VertexOut in [[stage_in]],
    constant float &time [[buffer(0)]]
) {
    float dist = length(in.uv); // 現在長度函數可以正確識別了
    
    // 呼吸效果：控制光暈的大小
    float breathe = 1.0 + 0.15 * sin(time * 3.0);
    
    // 畫出圓形，並乘上頂點傳過來的殘影衰減係數
    float alpha = (0.9 - smoothstep(0.4 * breathe, 0.5 * breathe, dist)) * in.trailAlpha;
    
    // 指數發光效果，同樣受殘影衰減影響
    float glow = exp(-dist * 3.5) * 0.6 * breathe * in.trailAlpha;
    
    // 最終輸出：本體顏色 + 光暈
    return float4(in.color + glow, alpha + glow);
}
