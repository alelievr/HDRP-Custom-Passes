Shader "Hidden/FullScreen/Blur"
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
    float _Radius;
    float _UVScale;
    float _InvertMask;

    float3 BlurPixels(float3 taps[9])
    {
        return 0.27343750 * (taps[4]          )
             + 0.21875000 * (taps[3] + taps[5])
             + 0.10937500 * (taps[2] + taps[6])
             + 0.03125000 * (taps[1] + taps[7])
             + 0.00390625 * (taps[0] + taps[8]);
    }

    float4 HorizontalBlur(Varyings varyings) : SV_Target
    {
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);

        // Horizontal blur from the camera color buffer
        float2 offset = _ScreenSize.zw * _Radius;
        float3 taps[9];
        for (int i = -4; i <= 4; i++)
        {
            // We ned to multiply the UV by _UVScale here because the allocated buffer we are sampling have a scale of 0.5 (See the buffer allocation)
            float2 uv = (posInput.positionNDC.xy + float2(i, 0) * offset) * _UVScale * _RTHandleScale.xy;
            uv = clamp(uv, 0, _RTHandleScale.xy - _ScreenSize.zw); // clamp UV to 1 pixel to avoid bleeding
            taps[i + 4] = SAMPLE_TEXTURE2D_X_LOD(_Source, s_linear_clamp_sampler, uv, 0).rgb;
        }

        return float4(BlurPixels(taps), 1);
    }

    float4 VerticalBlur(Varyings varyings) : SV_Target
    {
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);

        // Vertical blur from the blur color buffer
        // We use the Uv scale here to know if we render to a half res target, if we do then we adjust the offset
        // by multiplying by 1 and 2 othersize because the offset in the horizontal pass already have this scale
        // built-in ... TODO: Ask julien if we can simplify this
        float2 offset = _ScreenSize.zw * _Radius * (_UVScale == 2 ? 1 : 2);
        float3 taps[9];
        for (int i = -4; i <= 4; i++)
        {
            float2 uv = (posInput.positionNDC.xy + float2(0, i) * offset) * _UVScale * _RTHandleScale.xy;
            uv = clamp(uv, 0, _RTHandleScale.xy - _ScreenSize.zw); // clamp UV to 1 pixel to avoid bleeding
            taps[i + 4] = SAMPLE_TEXTURE2D_X_LOD(_Source, s_linear_clamp_sampler, uv, 0).rgb;
        }

        return float4(BlurPixels(taps), 1);
    }

    float4 CompositeMaskedBlur(Varyings varyings) : SV_Target
    {
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);
        float2 uv = posInput.positionNDC.xy * _RTHandleScale.xy;
        // TODO: make a function from this:
        uv = clamp(uv, 0, _RTHandleScale.xy - _ScreenSize.zw); // clamp UV to 1 pixel to avoid bleeding

        float4 colorBuffer = SAMPLE_TEXTURE2D_X_LOD(_ColorBufferCopy, s_linear_clamp_sampler, uv, 0).rgba;
        float4 blurredBuffer = SAMPLE_TEXTURE2D_X_LOD(_Source, s_linear_clamp_sampler, uv, 0).rgba;
        float4 mask = SAMPLE_TEXTURE2D_X_LOD(_Mask, s_linear_clamp_sampler, uv, 0);
        float maskDepth = SAMPLE_TEXTURE2D_X_LOD(_MaskDepth, s_linear_clamp_sampler, uv, 0).r;
        float maskValue = 0;

        maskValue = any(mask.rgb > 0.1) || (maskDepth > depth);

        if (_InvertMask > 0.5)
            maskValue = !maskValue;

        return float4(lerp(blurredBuffer.rgb, colorBuffer.rgb, maskValue), colorBuffer.a);
    }

    ENDHLSL

    SubShader
    {
        Pass
        {
            // Horizontal Blur from the camera color LOD
            Name "Horizontal Blur"

            ZWrite Off
            ZTest Always
            Blend Off
            Cull Off

            HLSLPROGRAM
                #pragma fragment HorizontalBlur
            ENDHLSL
        }

        Pass
        {
            // Vertical Blur from the blur buffer back to camera color
            Name "Vertical Blur"

            ZWrite Off
            ZTest Always
            Blend Off
            Cull Off

            HLSLPROGRAM
                #pragma fragment VerticalBlur
            ENDHLSL
        }

        Pass
        {
            // Vertical Blur from the blur buffer back to camera color
            Name "Composite Blur and Color using a mask"

            ZWrite Off
            ZTest Always
            Blend Off
            Cull Off

            HLSLPROGRAM
                #pragma fragment CompositeMaskedBlur
            ENDHLSL
        }
    }
    Fallback Off
}
