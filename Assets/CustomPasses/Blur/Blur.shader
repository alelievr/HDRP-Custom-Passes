Shader "FullScreen/Blur"
{
    HLSLINCLUDE

    #pragma vertex Vert

    #pragma target 4.5
    #pragma only_renderers d3d11 ps4 xboxone vulkan metal switch

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

    TEXTURE2D_X(_BlurBuffer);
    float _Radius;

    float3 BlurPixels(float3 taps[9])
    {
        return 0.27343750 * (taps[4]    )
             + 0.21875000 * (taps[3] + taps[5])
             + 0.10937500 * (taps[2] + taps[6])
             + 0.03125000 * (taps[1] + taps[7])
             + 0.00390625 * (taps[0] + taps[8]);
    }

    float4 FullScreenPass(Varyings varyings) : SV_Target
    {
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);

        // Horizontal blur from the camera color buffer
        float2 offset = float2(1, 0) * _ScreenSize.zw * _Radius;
        float3 taps[9];
        for (int i = -4; i <= 4; i++)
            taps[i + 4] = CustomPassSampleCameraColor(posInput.positionNDC.xy + float2(i, 0) * offset, 0);

        return float4(BlurPixels(taps), 1);
    }

    float4 VerticalBlur(Varyings varyings) : SV_Target
    {
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);

        // Vertical blur from the blur color buffer
        float2 offset = float2(0, 1) * _ScreenSize.zw * _Radius;
        float3 taps[9];
        for (int i = -4; i <= 4; i++)
            taps[i + 4] = SAMPLE_TEXTURE2D_X_LOD(_BlurBuffer, s_linear_clamp_sampler, (posInput.positionNDC.xy + float2(0, i) * offset) * _RTHandleScale.xy, 0).rgb;

        return float4(BlurPixels(taps), 1);
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
                #pragma fragment FullScreenPass
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
    }
    Fallback Off
}
