Shader "FullScreen/TransparentAtmosphericScattering"
{
    HLSLINCLUDE

    #pragma vertex Vert

    #pragma target 4.5
    #pragma only_renderers d3d11 playstation xboxone xboxseries vulkan metal switch

    #pragma enable_d3d11_debug_symbols

    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/CustomPass/CustomPassCommon.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/AtmosphericScattering/AtmosphericScattering.hlsl"
    #include "MBOIT.hlsl"

    TEXTURE2D_X(_MomentOIT);
    TEXTURE2D_X(_MomentZeroOIT);
    // TEXTURE2D_X(_AccumulatedColorOIT);
    TEXTURE2D_X(_ResolvedMoments); 

    #define FAR_PLANE_DEPTH 1

    struct FragOutput
    {
        float4 moments : SV_Target0;
        float zeroth_moment : SV_Target1;
    };

    float RemapDepth(float linearDepth)
    {
        float depth01 = linearDepth / 1000;
        return depth01 * 2 - 1; // depth between -1 and 1 
    }

    FragOutput GenerateMoments(Varyings varyings)
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);
        float3 V = GetWorldSpaceNormalizeViewDir(posInput.positionWS);

        float3 color, opacity;
        EvaluateAtmosphericScattering(posInput, V, color, opacity); // Premultiplied alpha

        // TODO: support polychromatic opacity in moment, how?

        FragOutput output = (FragOutput)0;
        generateMoments(RemapDepth(posInput.linearDepth), max(0.000001, 1 - opacity.x), output.zeroth_moment, output.moments);
        return output;
    }

    float4 ResolveMoments(Varyings varyings) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);
        float3 V = GetWorldSpaceNormalizeViewDir(posInput.positionWS);
        float4 outColor; 

        float3 color, opacity;
        EvaluateAtmosphericScattering(posInput, V, color, opacity); // Premultiplied alpha

        // TODO: support polychromatic opacity in moment, how?

        // Sample moment textures
        float4 momentData = LOAD_TEXTURE2D_X(_MomentOIT, posInput.positionSS);
        float zerothMoment = LOAD_TEXTURE2D_X(_MomentZeroOIT, posInput.positionSS).x;

        if (zerothMoment == 0)
        {
            outColor = 0;
        }
        else
        {
            // Reconstruct transmittance from the moments using depth and moments (section 3.2)
            float transmittanceAtDepth, totalTransmittance;
            resolveMoments(transmittanceAtDepth, totalTransmittance, RemapDepth(posInput.linearDepth), zerothMoment, momentData);
        
            outColor = float4(color * opacity.x * transmittanceAtDepth, opacity.x * transmittanceAtDepth);
        }

        return outColor;
    }

    ENDHLSL

    SubShader
    {
        Tags{ "RenderPipeline" = "HDRenderPipeline" }
        Pass
        {
            Name "GenerateMoments"

            ZWrite Off
            ZTest Always
            Blend One One 
            Cull Off

            HLSLPROGRAM
                #pragma fragment GenerateMoments
            ENDHLSL
        }

        Pass
        {
            Name "ResolveMoments"

            ZWrite Off
            ZTest Always
            Blend One One 
            Cull Off

            HLSLPROGRAM
                #pragma fragment ResolveMoments 
            ENDHLSL
        }
    }
    Fallback Off
}
