Shader "Hidden/FullScreen/CurrentDepthToCustomDepth"
{
    HLSLINCLUDE

    #pragma vertex Vert

    #pragma target 4.5
    #pragma only_renderers d3d11 playstation xboxone xboxseries vulkan metal switch

    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/CustomPass/CustomPassCommon.hlsl"
    #pragma enable_d3d11_debug_symbols

    TEXTURE2D_X(_CurrentCameraDepth);
    TEXTURE2D_X_MSAA(float, _CurrentCameraDepthMSAA);
    
    int _MSAASampleCount;

    float FullScreenPass(Varyings varyings) : SV_Depth
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);

        if (_MSAASampleCount > 1)
        {
            // Resolve MSAA depth:
            float depth = 10000000.0f;
            for (int i = 0; i < _MSAASampleCount; i++)
                depth = min(depth, LOAD_TEXTURE2D_X_MSAA(_CurrentCameraDepthMSAA, uint2(varyings.positionCS.xy), i));
            return depth;
        }
        else
            return LOAD_TEXTURE2D_X(_CurrentCameraDepth, uint2(varyings.positionCS.xy));
    }

    ENDHLSL

    SubShader
    {
        Tags{ "RenderPipeline" = "HDRenderPipeline" }
        Pass
        {
            Name "Custom Pass 0"

            ZWrite On
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
