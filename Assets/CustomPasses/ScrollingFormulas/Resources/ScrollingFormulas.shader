Shader "FullScreen/ScrollingFormulas"
{
    Properties
    {
        _TriplanarTexture("Triplanar Texture", 2D) = "white" {}
        _Scale("Scale", Float) = 0.2
        _Power("Power", Float) = 1
        _SphereSize ("Sphere size", float) = 5
        _SphereOrigin("Sphere origin", Vector) = (0,0,0,0)
    }

    HLSLINCLUDE

    #pragma vertex Vert

    #pragma target 4.5
    #pragma only_renderers d3d11 ps4 xboxone vulkan metal switch

    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/CustomPass/CustomPassCommon.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/NormalBuffer.hlsl"

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

    TEXTURE2D(_TriplanarTexture);
    float _Scale;
    float _Power;
    float _SphereSize;
    float3 _SphereOrigin;

    float4 FullScreenPass(Varyings varyings) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);

        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);
        float3 viewDirection = GetWorldSpaceNormalizeViewDir(posInput.positionWS);
        float4 color = float4(0.0, 0.0, 0.0, 0.0);

        float3 worldPos = GetAbsolutePositionWS(posInput.positionWS);
        worldPos -= _SphereOrigin;
        
        NormalData normalData;
        DecodeFromNormalBuffer(varyings.positionCS.xy, normalData);
        float3 normal = normalData.normalWS;

        float3 offsetedPosition = worldPos.xyz - float3(0, 0, _SphereSize);
        float2 uvX = offsetedPosition.zy * _Scale;
        float2 uvY = offsetedPosition.xz * _Scale;
        float2 uvZ = offsetedPosition.xy * _Scale;

        float4 colorX = SAMPLE_TEXTURE2D(_TriplanarTexture, s_trilinear_repeat_sampler, uvX).rgba;
        float4 colorY = SAMPLE_TEXTURE2D(_TriplanarTexture, s_trilinear_repeat_sampler, uvY).rgba;
        float4 colorZ = SAMPLE_TEXTURE2D(_TriplanarTexture, s_trilinear_repeat_sampler, uvZ).rgba;

        float3 s = sign(normal);
        normal = normalize(pow(abs(normal), _Power)) * s;
        color = colorX * abs(normal.x) + colorY * abs(normal.y) + colorZ * abs(normal.z);

        float d = saturate((worldPos.z - _SphereSize) / 5.0);
        color.a *= d;

        // Fade value allow you to increase the strength of the effect while the camera gets closer to the custom pass volume
        float f = 1 - abs(_FadeValue * 2 - 1);
        return float4(color.rgb + f, color.a);
    }

    ENDHLSL

    SubShader
    {
        Pass
        {
            Name "Custom Pass 0"

            ZWrite Off
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off

            HLSLPROGRAM
                #pragma fragment FullScreenPass
            ENDHLSL
        }
    }
    Fallback Off
}
