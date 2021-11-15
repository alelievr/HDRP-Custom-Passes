Shader "Hidden/Renderers/ForegroundDepthClear"
{
    HLSLINCLUDE

    #pragma target 4.5
    #pragma only_renderers d3d11 playstation xboxone xboxseries vulkan metal switch

    // #pragma enable_d3d11_debug_symbols

    //enable GPU instancing support
    #pragma multi_compile_instancing
    #pragma multi_compile _ DOTS_INSTANCING_ON

    ENDHLSL

    SubShader
    {
        Pass
        {
            Name "FirstPass"
            Tags { "LightMode" = "FirstPass" }

            Blend Off
            ZWrite On 
            ZTest Always 
            ColorMask 0

            Cull Back

            HLSLPROGRAM

            // Toggle the alpha test
            #define _ALPHATEST_ON

            // Toggle transparency

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

            float4 Vert (float4 vertex : POSITION) : SV_POSITION
            {
                return mul(UNITY_MATRIX_VP, mul(UNITY_MATRIX_M, float4(vertex.xyz, 1.0)));
            }

            float4 Frag (float4 vertex : SV_POSITION, out float depth : SV_Depth) : SV_Target
            {
                depth = 0;
                return 0;
            }

            #pragma vertex Vert
            #pragma fragment Frag

            ENDHLSL
        }
    }
}
