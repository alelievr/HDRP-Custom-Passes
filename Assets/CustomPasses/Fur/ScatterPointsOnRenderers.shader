Shader "Hidden/Fur/ScatterPointsOnRenderers"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _ColorMap("ColorMap", 2D) = "white" {}

        // Transparency
        _AlphaCutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
    }

    HLSLINCLUDE

    #pragma target 4.5
    #pragma only_renderers d3d11 ps4 xboxone vulkan metal switch

    // #pragma enable_d3d11_debug_symbols

    //enable GPU instancing support
    #pragma multi_compile_instancing

    ENDHLSL

    SubShader
    {
        Pass
        {
            Name "FirstPass"
            Tags { "LightMode" = "FirstPass" }

            Blend Off
            ZWrite Off
            ZTest LEqual

            Cull Back

            HLSLPROGRAM

            // Toggle the alpha test
            #define _ALPHATEST_ON

            // Toggle transparency
            // #define _SURFACE_TYPE_TRANSPARENT

            // Toggle fog on transparent
            #define _ENABLE_FOG_ON_TRANSPARENT
            
            // List all the attributes needed in your shader (will be passed to the vertex shader)
            // you can see the complete list of these attributes in VaryingMesh.hlsl
            #define ATTRIBUTES_NEED_TEXCOORD0
            #define ATTRIBUTES_NEED_NORMAL
            #define ATTRIBUTES_NEED_TANGENT

            // List all the varyings needed in your fragment shader
            #define VARYINGS_NEED_POSITION_WS
            #define VARYINGS_NEED_TEXCOORD0
            #define VARYINGS_NEED_TANGENT_TO_WORLD
            
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/CustomPass/CustomPassRenderers.hlsl"

            TEXTURE2D(_ColorMap);
            float4 _ColorMap_ST;
            float4 _Color;

            struct DrawArgument
            {
                uint    vertexCount;
                uint    instanceCount;
                uint    firstVertex;
                uint    firstInstance;
            };

            struct FurData
            {
                float3 position;
            };

            RWStructuredBuffer<FurData> furData;
            RWStructuredBuffer<DrawArgument> drawArgs;

            // If you need to modify the vertex datas, you can uncomment this code
            // Note: all the transformations here are done in object space
            // #define HAVE_MESH_MODIFICATION
            // AttributesMesh ApplyMeshModification(AttributesMesh input, float3 timeParameters)
            // {
            //     input.positionOS += input.normalOS * 0.0001; // inflate a bit the mesh to avoid z-fight
            //     return input;
            // }

            #pragma enable_d3d11_debug_symbols

            void GetSurfaceAndBuiltinData(FragInputs fragInputs, float3 viewDirection, inout PositionInputs posInput, out SurfaceData surfaceData, out BuiltinData builtinData)
            {
                // clip(-1); // Discard all pixels
                float2 colorMapUv = TRANSFORM_TEX(fragInputs.texCoord0.xy, _ColorMap);
                float4 result = SAMPLE_TEXTURE2D(_ColorMap, s_trilinear_clamp_sampler, colorMapUv) * _Color;
                float opacity = result.a;
                float3 color = float3(0, 0, 0);
                float3 positionWS = GetAbsolutePositionWS(fragInputs.positionRWS);
                float3 positionOS = TransformWorldToObject(fragInputs.positionRWS);

                float2 threshold = abs(float2(ddx(fragInputs.texCoord0.x), ddy(fragInputs.texCoord0.y)));
                float2 a = abs(fragInputs.texCoord0.xy * 2 - 1);

                if (all(fragInputs.texCoord0.xy < threshold))
                // if (all(a <= threshold * 1.5))
                {
                    // color = float3(1, 0, 1);
                    // int index = furData.IncrementCounter();
                    // furData[index].position = fragInputs.positionRWS;
                }
                // color = threshold.xyx * 100;

#ifdef _ALPHATEST_ON
                DoAlphaTest(opacity, _AlphaCutoff);
#endif

                // Write back the data to the output structures
                ZERO_INITIALIZE(BuiltinData, builtinData); // No call to InitBuiltinData as we don't have any lighting
                ZERO_INITIALIZE(SurfaceData, surfaceData); // No call to InitBuiltinData as we don't have any lighting
                builtinData.opacity = opacity;
                builtinData.emissiveColor = float3(0, 0, 0);
                // surfaceData.color = color;
                surfaceData.color = float3(fragInputs.texCoord0.xy, 0);
            }

            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/ShaderPassForwardUnlit.hlsl"
            
            // Geometry shader must be after the shaderpass include otherwise we dont' have the good structs
            [maxvertexcount(3)]
            void geom (triangle PackedVaryingsType input[3], inout TriangleStream<PackedVaryingsType> tristream){

                // Send the triangles to furData
                float4 c1 = mul(float4(input[0].vmesh.positionCS.xyz, 0), UNITY_MATRIX_I_VP);
                float4 c2 = mul(float4(input[1].vmesh.positionCS.xyz, 0), UNITY_MATRIX_I_VP);
                float4 c3 = mul(float4(input[2].vmesh.positionCS.xyz, 0), UNITY_MATRIX_I_VP);
                int index = furData.IncrementCounter() * 3;
                furData[index + 0].position = c1.xyz;
                furData[index + 1].position = c2.xyz;
                furData[index + 2].position = c3.xyz;

                drawArgs[0].instanceCount = index;

                // input[0].vmesh.interpolators0.xyz = 100;
                // input[0].vmesh.interpolators3.xy = 0;
                // input[0].vmesh.positionCS.xyz += 1;

                // Copy data to render the unchanged mesh
                tristream.Append(input[0]);
                tristream.Append(input[1]);
                tristream.Append(input[2]);
            }

            #pragma vertex Vert
            #pragma fragment Frag
            #pragma require geometry
            #pragma geometry geom

            ENDHLSL
        }
    }
}
