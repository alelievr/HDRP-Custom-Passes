#include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/CustomPass/CustomPassCommon.hlsl"

void SampleCustomBuffer_float(float2 UV, out float4 Color, out float Depth)
{
#if SHADERGRAPH_PREVIEW == 1
    Color = float4(0, 0, 0, 1);
    Depth = 0;
#else
    Color = SampleCustomColor(UV);
    Depth = LinearEyeDepth(SampleCustomDepth(UV), _ZBufferParams);
#endif
}