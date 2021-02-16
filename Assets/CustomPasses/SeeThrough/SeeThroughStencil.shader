Shader "Hidden/Renderers/SeeThroughStencil"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _ColorMap("ColorMap", 2D) = "white" {}

        // Transparency
        _AlphaCutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        [HideInInspector]_StencilWriteMask("_StencilWriteMask", Float) = 0
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
            ColorMask 0
            Cull Back

            Stencil
            {
                Ref -1
                Comp Always
                WriteMask [_StencilWriteMask]
                Pass replace
            }

            HLSLPROGRAM

            // List all the attributes needed in your shader (will be passed to the vertex shader)
            // // you can see the complete list of these attributes in VaryingMesh.hlsl
            // #define ATTRIBUTES_NEED_TEXCOORD0
            // #define ATTRIBUTES_NEED_NORMAL
            // #define ATTRIBUTES_NEED_TANGENT

            // // List all the varyings needed in your fragment shader
            // #define VARYINGS_NEED_TEXCOORD0
            // #define VARYINGS_NEED_TANGENT_TO_WORLD

            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/CustomPass/CustomPassRenderers.hlsl"

            void GetSurfaceAndBuiltinData(FragInputs fragInputs, float3 viewDirection, inout PositionInputs posInput, out SurfaceData surfaceData, out BuiltinData builtinData)
            {
                // Write back the data to the output structures
                ZERO_INITIALIZE(BuiltinData, builtinData);
                ZERO_INITIALIZE(SurfaceData, surfaceData);
                surfaceData.color = 1;
            }

            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/ShaderPassForwardUnlit.hlsl"

            #pragma vertex Vert
            #pragma fragment Frag

            ENDHLSL
        }
    }
}
