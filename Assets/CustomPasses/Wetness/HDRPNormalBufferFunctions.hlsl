#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/TextureXR.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/NormalBuffer.hlsl"


void EncodeIntoNormalBuffer_float(float3 normalWS, float smoothness, out float4 outNormalBuffer)
{
    NormalData normalData;
    normalData.normalWS = normalWS;
    normalData.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(smoothness);

    EncodeIntoNormalBuffer(normalData, outNormalBuffer);
}