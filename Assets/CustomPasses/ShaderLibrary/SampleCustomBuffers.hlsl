#if SHADERGRAPH_PREVIEW == 0
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/CustomPass/CustomPassCommon.hlsl"
#endif

void SampleCustomColor_float(float2 UV, out float4 Color)
{
#if SHADERGRAPH_PREVIEW == 1
    Color = float4(0, 0, 0, 1);
#else
    Color = SampleCustomColor(UV);
#endif
}

void SampleCustomColor_half(half2 UV, out half4 Color)
{
#if SHADERGRAPH_PREVIEW == 1
    Color = half4(0, 0, 0, 1);
#else
    Color = SampleCustomColor(UV);
#endif
}

void SampleCustomDepth_float(float2 UV, out float Depth)
{
#if SHADERGRAPH_PREVIEW == 1
    Depth = 0;
#else
    Depth = LinearEyeDepth(SampleCustomDepth(UV), _ZBufferParams);
#endif
}

void SampleCustomDepth_half(half2 UV, out half Depth)
{
#if SHADERGRAPH_PREVIEW == 1
    Depth = 0;
#else
    Depth = LinearEyeDepth(SampleCustomDepth(UV), _ZBufferParams);
#endif
}