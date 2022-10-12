Shader "FullScreen/Wetness"
{
    properties
    {
        _TriplanarTexture("Triplanar Texture", 2D) = "normal" {}
        _Power("Power", Float) = 1
        _WaterRoughness("_WaterRoughness", Float) = 1
        _Intensity("_Intensity", Float) = 1
        _Scale("_Scale", Float) = 1
    }
    
    HLSLINCLUDE

    #pragma vertex Vert

    #pragma target 4.5
    #pragma only_renderers d3d11 playstation xboxone xboxseries vulkan metal switch

    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/CustomPass/CustomPassCommon.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/NormalBuffer.hlsl"

    TEXTURE2D(_TriplanarTexture);
    TEXTURE2D_X(_NormalBufferSource);
    float _Intensity;
    float _WaterRoughness;
    float _Power;
    float _Scale;

    float4 FullScreenPass(Varyings varyings) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);

        // Decode normal
        NormalData normalData;
        float4 encodedNormalData = LOAD_TEXTURE2D_X_LOD(_NormalBufferSource, varyings.positionCS.xy, 0);
        DecodeFromNormalBuffer(encodedNormalData, normalData);


        float3 worldPos = GetAbsolutePositionWS(posInput.positionWS);
        
        float4 colorX = SAMPLE_TEXTURE2D(_TriplanarTexture, s_trilinear_repeat_sampler, worldPos.zy * _Scale).rgba * 2 - 1;
        float4 colorY = SAMPLE_TEXTURE2D(_TriplanarTexture, s_trilinear_repeat_sampler, worldPos.xz * _Scale).rgba;
        float4 colorZ = SAMPLE_TEXTURE2D(_TriplanarTexture, s_trilinear_repeat_sampler, worldPos.xy * _Scale).rgba;

        // float3 normal = normalData.normalWS;
        float3 normal = float3(colorX.x, 1, colorX.y);
        float3 s = sign(normal);
        normal = normalize(pow(abs(normal), _Power)) * s;
        float3 normalModifier = normalize(colorX * abs(normal.x) + colorY * abs(normal.y) + colorZ * abs(normal.z));

        // FIXME
        float3 upNormal = normalize(float3(colorY.x, 1, colorY.y));
        normalData.normalWS = lerp(normalData.normalWS, upNormal, saturate(dot(normalData.normalWS, float3(0, 1, 0)) * 1));
        // normalData.perceptualRoughness = 0;
        // normalData.normalWS = upNormal;

        // Encode normal
        EncodeIntoNormalBuffer(normalData, encodedNormalData);

        return encodedNormalData;
    }

    ENDHLSL

    SubShader
    {
        Tags{ "RenderPipeline" = "HDRenderPipeline" }
        Pass
        {
            Name "Custom Pass 0"

            ZWrite Off
            ZTest Always
            Blend Off
            Cull Off

            HLSLPROGRAM
                #pragma fragment FullScreenPass
            ENDHLSL
        }
    }
    Fallback Off
}
