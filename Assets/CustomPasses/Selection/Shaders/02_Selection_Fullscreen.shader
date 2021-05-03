Shader "02_Selection/Fullscreen"
{
    properties
    {
        _SamplePrecision ("Sampling Precision", Range(1,3) ) = 1
        _OutlineWidth ("Outline Width", Float ) = 5
        
        _InnerColor ("Inner Color", Color) = (1, 1, 0, 0.5)
        _OuterColor( "Outer Color", Color ) = (1, 1, 0, 1)
        _Texture ("Texture", 2D ) = "black" {}
        _TextureSize("Texture Pixels Size", Vector) = (64,64,0,0)
        
        _BehindFactor("Behind Factor", Range(0,1)) = 0.2
    }

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
    
    #define v2 1.41421
    #define c45 0.707107
    #define c225 0.9238795
    #define s225 0.3826834
    
    #define MAXSAMPLES 16
    static float2 offsets[MAXSAMPLES] = {
        float2( 1, 0 ),
        float2( -1, 0 ),
        float2( 0, 1 ),
        float2( 0, -1 ),
        
        float2( c45, c45 ),
        float2( c45, -c45 ),
        float2( -c45, c45 ),
        float2( -c45, -c45 ),
        
        float2( c225, s225 ),
        float2( c225, -s225 ),
        float2( -c225, s225 ),
        float2( -c225, -s225 ),
        float2( s225, c225 ),
        float2( s225, -c225 ),
        float2( -s225, c225 ),
        float2( -s225, -c225 )
    };
    
    int _SamplePrecision;
    float _OutlineWidth;
    
    float4 _InnerColor;
    float4 _OuterColor;
    
    Texture2D _Texture;
    float2 _TextureSize;
    
    float _BehindFactor;

    float4 FullScreenPass(Varyings varyings) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);

        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);
        float3 viewDirection = GetWorldSpaceNormalizeViewDir(posInput.positionWS);
        
        float d = LoadCustomDepth(posInput.positionSS);
        float db = LoadCameraDepth(posInput.positionSS);
        
        float alphaFactor = (db>d)?_BehindFactor:1;

		float4 c = LoadCustomColor(posInput.positionSS);

        float obj = c.a;
        
        uint offset = 5;
        
        uint sampleCount = min( 2 * pow(2, _SamplePrecision ), MAXSAMPLES ) ;
        
        float4 outline = float4(0,0,0,0);
        
        float2 uvOffsetPerPixel = 1.0/_ScreenSize .xy;
        
        for (uint i=0 ; i<sampleCount ; ++i )
        {
            outline =  max( SampleCustomColor( posInput.positionNDC + uvOffsetPerPixel * _OutlineWidth * offsets[i] ), outline );
        }

        float4 o = float4(0,0,0,0);
        
        float4 innerColor = SAMPLE_TEXTURE2D( _Texture, s_trilinear_repeat_sampler, posInput.positionSS / _TextureSize) * _InnerColor;
        
        innerColor.a *= alphaFactor;
        
        o = lerp(o, _OuterColor * float4(outline.rgb, 1), outline.a);
        
        o = lerp( o, innerColor * float4(c.rgb, 1), obj);
        
        return o;
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
