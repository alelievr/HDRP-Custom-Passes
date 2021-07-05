Shader "Hidden/FullScreen/CustomCopy"
{
    HLSLINCLUDE

    #pragma vertex Vert

    #pragma target 4.5
    #pragma only_renderers d3d11 playstation xboxone xboxseries vulkan metal switch

    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/CustomPass/CustomPassCommon.hlsl"

    float4 _Scale;
    float4 SampleBuffer(PositionInputs posInput);

    float4 FullScreenPass(Varyings varyings) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);

        return SampleBuffer(posInput);
    }

    ENDHLSL


    SubShader
    {
        Pass
        {
            Name "Normal"

            ZWrite Off
            ZTest Always
            Blend Off
            Cull Off

            HLSLPROGRAM

            #pragma fragment FullScreenPass

            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/NormalBuffer.hlsl"
            float4 SampleBuffer(PositionInputs posInput)
            {
                NormalData normalData;
                DecodeFromNormalBuffer(posInput.positionSS.xy, normalData);

                return float4(normalData.normalWS, 1);
            }

            ENDHLSL
        }

        Pass
        {
            Name "Roughness"

            ZWrite Off
            ZTest Always
            Blend Off
            Cull Off

            HLSLPROGRAM

            #pragma fragment FullScreenPass

            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/NormalBuffer.hlsl"
            float4 SampleBuffer(PositionInputs posInput)
            {
                NormalData normalData;
                DecodeFromNormalBuffer(posInput.positionSS.xy, normalData);

                return float4(normalData.perceptualRoughness, 0, 0, 1);
            }

            ENDHLSL
        }

        Pass
        {
            Name "Depth"

            ZWrite Off
            ZTest Always
            Blend Off
            Cull Off

            HLSLPROGRAM

            #pragma fragment FullScreenPass

            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/NormalBuffer.hlsl"
            float4 SampleBuffer(PositionInputs posInput)
            {
                return float4(posInput.linearDepth, 0, 0, 1);
            }

            ENDHLSL
        }
    }
    Fallback Off
}
