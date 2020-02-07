Shader "FullScreen/TIPS"
{
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
    // float4 SampleCustomColor(float2 uv);
    // float4 LoadCustomColor(uint2 pixelCoords);
    // float LoadCustomDepth(uint2 pixelCoords);
    // float SampleCustomDepth(float2 uv);

    // There are also a lot of utility function you can use inside Common.hlsl and Color.hlsl,
    // you can check them out in the source code of the core SRP package.

    TEXTURE2D_X(_TIPSBuffer);
    float _EdgeDetectThreshold;
    float3 _GlowColor;
    float _EdgeRadius;
    float _BypassMeshDepth;

    float SampleClampedDepth(float2 uv) { return SampleCameraDepth(clamp(uv, _ScreenSize.zw, 1 - _ScreenSize.zw)).r; }

    float EdgeDetect(float2 uv, float depthThreshold, float normalThreshold)
    {
        normalThreshold *= _EdgeDetectThreshold;
        depthThreshold *= _EdgeDetectThreshold;
        float halfScaleFloor = floor(_EdgeRadius * 0.5);
        float halfScaleCeil = ceil(_EdgeRadius * 0.5);
    
        // Compute uv position to fetch depth informations
        float2 bottomLeftUV = uv - float2(_ScreenSize.zw.x, _ScreenSize.zw.y) * halfScaleFloor;
        float2 topRightUV = uv + float2(_ScreenSize.zw.x, _ScreenSize.zw.y) * halfScaleCeil;
        float2 bottomRightUV = uv + float2(_ScreenSize.zw.x * halfScaleCeil, -_ScreenSize.zw.y * halfScaleFloor);
        float2 topLeftUV = uv + float2(-_ScreenSize.zw.x * halfScaleFloor, _ScreenSize.zw.y * halfScaleCeil);
    
        // Depth from camera buffer
        float depth0 = SampleClampedDepth(bottomLeftUV);
        float depth1 = SampleClampedDepth(topRightUV);
        float depth2 = SampleClampedDepth(bottomRightUV);
        float depth3 = SampleClampedDepth(topLeftUV);
    
        float depthDerivative0 = depth1 - depth0;
        float depthDerivative1 = depth3 - depth2;
    
        float edgeDepth = sqrt(pow(depthDerivative0, 2) + pow(depthDerivative1, 2)) * 100;

        float newDepthThreshold = depthThreshold * depth0;
        edgeDepth = edgeDepth > newDepthThreshold ? 1 : 0;
    
        // Normals extracted from the camera normal buffer
        NormalData normalData0, normalData1, normalData2, normalData3;
        DecodeFromNormalBuffer(_ScreenSize.xy * bottomLeftUV, normalData0);
        DecodeFromNormalBuffer(_ScreenSize.xy * topRightUV, normalData1);
        DecodeFromNormalBuffer(_ScreenSize.xy * bottomRightUV, normalData2);
        DecodeFromNormalBuffer(_ScreenSize.xy * topLeftUV, normalData3);
    
        float3 normalFiniteDifference0 = normalData1.normalWS - normalData0.normalWS;
        float3 normalFiniteDifference1 = normalData3.normalWS - normalData2.normalWS;
    
        float edgeNormal = sqrt(dot(normalFiniteDifference0, normalFiniteDifference0) + dot(normalFiniteDifference1, normalFiniteDifference1));
        edgeNormal = edgeNormal > normalThreshold ? 1 : 0;

        // Combined
        return max(edgeDepth, edgeNormal);
    }

    float4 Compositing(Varyings varyings) : SV_Target
    {
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);
        float4 color = float4(0.0, 0.0, 0.0, 0.0);

        // Load the camera color buffer at the mip 0 if we're not at the before rendering injection point
        if (_CustomPassInjectionPoint != CUSTOMPASSINJECTIONPOINT_BEFORE_RENDERING)
            color = float4(CustomPassSampleCameraColor(posInput.positionNDC.xy, 0), 1);

        // Do some normal and depth based edge detection on the camera buffers.
        float3 edgeDetectColor = EdgeDetect(posInput.positionNDC.xy, 2, 1) * _GlowColor;
        // Remove the edge detect effect between the sky and objects when the object is inside the sphere
        edgeDetectColor *= depth != UNITY_RAW_FAR_CLIP_VALUE;

        // Load depth and color information from the custom buffer
        float meshDepthPos = LoadCustomDepth(posInput.positionSS.xy);
        float4 meshColor = LoadCustomColor(posInput.positionSS.xy);

        // Change the color of the icosahedron mesh
        meshColor = float4(_GlowColor, 1) * meshColor;

        // Transform the raw depth into eye space depth
        float sceneDepth = LinearEyeDepth(depth, _ZBufferParams);
        float meshDepth = LinearEyeDepth(meshDepthPos, _ZBufferParams);

        if (_BypassMeshDepth != 0)
            meshDepth = _BypassMeshDepth;

        // Add the intersection with mesh and scene depth to the edge detect result
        edgeDetectColor = lerp(edgeDetectColor, _GlowColor, saturate(2 - abs(meshDepth - sceneDepth) * 200 * rcp(_EdgeRadius)));

        // Blend the mesh color and edge detect color using the mesh alpha transparency
        float3 edgeMeshColor = lerp(edgeDetectColor, meshColor.xyz, (meshDepth < sceneDepth) ? meshColor.a : 0);

        // Avoid edge detection effect to leak inside the isocahedron mesh
        float3 finalColor = saturate(meshDepth - sceneDepth) > 0 ? color.xyz : edgeMeshColor;

        return float4(finalColor, 1);
    }

    // We need this copy because we can't sample and write to the same render target (Camera color buffer)
    float4 Copy(Varyings varyings) : SV_Target
    {
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);

        return float4(LOAD_TEXTURE2D_X_LOD(_TIPSBuffer, posInput.positionSS.xy, 0).rgb, 1);
    }

    // Try to remove fireflies
    float4 Blur(Varyings varyings) : SV_Target
    {
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        float meshDepth = LoadCustomDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);

        // It didn't worked :p
        return float4(LOAD_TEXTURE2D_X_LOD(_TIPSBuffer, posInput.positionSS.xy, 0).rgb, 1);
    
        float3 color = LOAD_TEXTURE2D_X_LOD(_TIPSBuffer, posInput.positionSS.xy, 0).rgb;

        // don't blur non outlined image
        if (LinearEyeDepth(depth, _ZBufferParams) < LinearEyeDepth(meshDepth, _ZBufferParams) + 0.1)
            return float4(color.r, 0, 0, 1);

        float3 t;
        for (float x = -1; x <= 1; x++)
        for (float y = -1; y <= 1; y++)
        {
            t += LOAD_TEXTURE2D_X_LOD(_TIPSBuffer, posInput.positionSS.xy + float2(x, y), 0).rgb;
        }

        if (Luminance(t) < Luminance(_GlowColor) * 3)
            color = 0;

        return float4(color, 1);
    }

    ENDHLSL

    SubShader
    {
        Pass
        {
            Name "Compositing"

            ZWrite Off
            ZTest Always
            Blend Off
            Cull Off

            HLSLPROGRAM
                #pragma fragment Compositing
            ENDHLSL
        }

        Pass
        {
            Name "Copy"

            ZWrite Off
            ZTest Always
            Blend Off
            Cull Off

            HLSLPROGRAM
                #pragma fragment Copy
            ENDHLSL
        }

        Pass
        {
            Name "Blur"

            ZWrite Off
            ZTest Always
            Blend Off
            Cull Off

            HLSLPROGRAM
                #pragma fragment Blur
            ENDHLSL
        }
    }
    Fallback Off
}
