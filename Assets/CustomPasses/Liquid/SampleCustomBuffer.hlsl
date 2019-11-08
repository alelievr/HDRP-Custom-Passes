#include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/CustomPass/CustomPassCommon.hlsl"

void SampleCustomBuffer_float(float2 UV, out float4 Color, out float Depth)
{
    Color = SampleCustomColor(UV);
    Depth = LinearEyeDepth(SampleCustomDepth(UV), _ZBufferParams);
}