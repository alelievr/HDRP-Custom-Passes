Shader "Hidden/FullScreen/ForegroundCompositing"
{
    HLSLINCLUDE

    #pragma vertex Vert

    #pragma target 4.5
    #pragma only_renderers d3d11 playstation xboxone xboxseries vulkan metal switch

    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/CustomPass/CustomPassCommon.hlsl"

    void FullScreenPass(Varyings varyings, out float4 outColor : SV_Target0, out float4 outMV : SV_Target1, out float outDepth : SV_Depth)
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);

        float4 foregroundColor = CustomPassLoadCustomColor(varyings.positionCS.xy);
        float foregroundDepth = CustomPassLoadCustomDepth(varyings.positionCS.xy);

        if (foregroundDepth == 0)
            clip(-1);

        // Overwrite camera color with foreground color
        outColor = foregroundColor;
        // Nuke depth in the camera so that most of the screen space effects ignore the foreground layer.
        outDepth = 1.0; // 1 is the nearest from the camera, it reduces ghosting with motion vectors
        // Also nuke motion vectors to avoid motion blur bleeding inside the foreground layer
        outMV = 0;
    }

    ENDHLSL

    SubShader
    {
        Tags{ "RenderPipeline" = "HDRenderPipeline" }
        Pass
        {
            Name "Compositing"

            ZWrite On
            ZTest Always
            Blend Off
            Cull Off

            // This stencil block will enable the stencil bit "ExcludeFromTUAndAA" which remove temporal artifacts.
            Stencil
            {
                Ref 1
                Comp Always
                Pass Replace
                WriteMask 1
            }

            HLSLPROGRAM
                #pragma fragment FullScreenPass
            ENDHLSL
        }
    }
    Fallback Off
}
