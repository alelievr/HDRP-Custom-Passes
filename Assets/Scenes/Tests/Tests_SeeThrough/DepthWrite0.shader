Shader "Renderers/DepthWrite0"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _ColorMap("ColorMap", 2D) = "white" {}
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
            Tags { "LightMode" = "ForwardOnly" }

            Blend Off
            ZWrite On
            ZTest Greater

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
            #define VARYINGS_NEED_TEXCOORD0
            #define VARYINGS_NEED_TANGENT_TO_WORLD

            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/CustomPass/CustomPassRenderers.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/VertMesh.hlsl"

            PackedVaryingsType Vert(AttributesMesh inputMesh)
            {
                VaryingsType varyingsType;
                varyingsType.vmesh = VertMesh(inputMesh);
                return PackVaryingsType(varyingsType);
            }

            float4 Frag(PackedVaryingsToPS packedInput, out float outputDepth : SV_Depth) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(packedInput);
                FragInputs input = UnpackVaryingsMeshToFragInputs(packedInput.vmesh);

                // input.positionSS is SV_Position
                PositionInputs posInput = GetPositionInput(input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionRWS);

                outputDepth = 0;
                
                return float4(0, 0, 0, 0);
            }

            #pragma vertex Vert
            #pragma fragment Frag

            ENDHLSL
        }
    }
}
