Shader "Hidden/Fullscreen/CompositeBlur"
{
    HLSLINCLUDE

    #pragma vertex Vert

    #pragma target 4.5
    #pragma only_renderers d3d11 ps4 xboxone vulkan metal switch
    #pragma enable_d3d11_debug_symbols

    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/CustomPass/CustomPassCommon.hlsl"

    // The PositionInputs struct allow you to retrieve a lot of useful information for your fullScreenShader:
    // struct PositionInputs
    // {
    //     float3 positionWS;  // World space position (could be camera-relative)
    //     float2 positionNDC; // Normalized screen coordinates within the viewport    : [0, 1) (with the half-pixel offset)
    //     uint2  positionSS;  // Screen space pixel coordinates                       : [0, NumPixels)
    //     uint2  tileCoord;   // Screen tile coordinates                              : [0, NumTiles)
    //     float  deviceDepth; // Depth from the depth buffer                          : [0, 1] (typically reversed)
    //     float  linearDepth; // View space Z coordinate                              : [Near, Far]
    // };

    // To sample custom buffers, you have access to these functions:
    // But be careful, on most platforms you can't sample to the bound color buffer. It means that you
    // can't use the SampleCustomColor when the pass color buffer is set to custom (and same for camera the buffer).
    // float3 SampleCustomColor(float2 uv);
    // float3 LoadCustomColor(uint2 pixelCoords);
    // float LoadCustomDepth(uint2 pixelCoords);
    // float SampleCustomDepth(float2 uv);

    // There are also a lot of utility function you can use inside Common.hlsl and Color.hlsl,
    // you can check them out in the source code of the core SRP package.

    TEXTURE2D_X(_Source);
    TEXTURE2D_X(_ColorBufferCopy);
    TEXTURE2D_X_HALF(_Mask);
    TEXTURE2D_X_HALF(_MaskDepth);
    float4 _ViewportSize;
    float _InvertMask;

    #pragma enable_d3d11_debug_symbols

    // We need to clamp the UVs to avoid bleeding from bigger render tragets (when we have multiple cameras)
    float2 ClampUVs(float2 uv)
    {
        uv = clamp(uv, 0, _RTHandleScale - _ScreenSize.zw * 2); // clamp UV to 1 pixel to avoid bleeding
        return uv;
    }

    float2 GetSampleUVs(Varyings varyings)
    {
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ViewportSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);
        return posInput.positionNDC.xy * _RTHandleScale.xy;
    }

    float4 CompositeMaskedBlur(Varyings varyings) : SV_Target
    {
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        float2 uv = ClampUVs(varyings.positionCS.xy * _ScreenSize.zw * _RTHandleScale.xy);

        float4 blurredBuffer = SAMPLE_TEXTURE2D_X_LOD(_Source, s_linear_clamp_sampler, uv, 0).rgba;
        float4 mask = SAMPLE_TEXTURE2D_X_LOD(_Mask, s_linear_clamp_sampler, uv, 0);
        float maskDepth = SAMPLE_TEXTURE2D_X_LOD(_MaskDepth, s_linear_clamp_sampler, uv, 0).r;
        float maskValue = 0;

        maskValue = any(mask.rgb > 0.1) || (maskDepth > depth - 0.0001 && maskDepth != 0);

        if (_InvertMask < 0.5)
            maskValue = !maskValue;

        return float4(blurredBuffer.rgb, maskValue);
    }

    ENDHLSL

    SubShader
    {
        Pass
        {
            // Vertical Blur from the blur buffer back to camera color
            Name "Composite Blur and Color using a mask"

            ZWrite Off
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off

            HLSLPROGRAM
                #pragma fragment CompositeMaskedBlur
            ENDHLSL
        }
    }
    Fallback Off
}
