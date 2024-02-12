Shader "FullScreen/ResolveOIT"
{
    HLSLINCLUDE

    #pragma vertex Vert

    #pragma target 4.5
    #pragma only_renderers d3d11 playstation xboxone xboxseries vulkan metal switch

    #pragma enable_d3d11_debug_symbols

    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/CustomPass/CustomPassCommon.hlsl"
    #include "MBOIT.hlsl"

    TEXTURE2D_X(_MomentOIT);
    TEXTURE2D_X(_MomentZeroOIT);
    // TEXTURE2D_X(_AccumulatedColorOIT);
    TEXTURE2D_X(_ResolvedMoments); 

    float4 FullScreenPass(Varyings varyings) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);
        float3 viewDirection = GetWorldSpaceNormalizeViewDir(posInput.positionWS);
        float4 color = float4(0.0, 0.0, 0.0, 0.0);

        float4 momentData = LOAD_TEXTURE2D_X(_MomentOIT, posInput.positionSS);
        float zerothMoment = LOAD_TEXTURE2D_X(_MomentZeroOIT, posInput.positionSS).x;
        // float4 accumulatedData = LOAD_TEXTURE2D_X(_AccumulatedColorOIT, posInput.positionSS);
        // float4 accumulatedColor = float4(accumulatedData.xyz, 1);// TODO: simplify: this alpha doesn't seem to be useful
        // float numberOfSurfaces = accumulatedData.w;

        // float td, tt;
        // resolveMoments(zerothMoment, momentData, td, tt, 0.0);

        float4 resolvedTransparentColor = LOAD_TEXTURE2D_X(_ResolvedMoments, posInput.positionSS);

        float3 opaqueColor = CustomPassLoadCameraColor(varyings.positionCS.xy, 0).rgb;
        // if (tt == 1.0)
        //     return float4(opaqueColor, 1);

        float transmittanceAtDepth, totalTransmittance; 
        resolveMoments(transmittanceAtDepth, totalTransmittance, 0.1, zerothMoment, momentData);
 
        // return float4(compositeOIT(opaqueColor, resolvedTransparentColor, totalTransmittance), 1);
        return float4(CompositeOIT2(zerothMoment, opaqueColor, resolvedTransparentColor.xyz, resolvedTransparentColor.a), 1);
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
