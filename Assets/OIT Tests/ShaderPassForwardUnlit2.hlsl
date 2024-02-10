#if SHADERPASS != SHADERPASS_FORWARD_UNLIT
#error SHADERPASS_is_not_correctly_define
#endif

// First stage
void generateMoments(float depth, float transmittance, out float b_0, out float4 b) {
    float absorbance = -log(transmittance);

	b_0 = absorbance;
	float depth_pow2 = depth * depth;
	float depth_pow4 = depth_pow2 * depth_pow2;
	b = float4(depth, depth_pow2, depth_pow2 * depth, depth_pow4) * absorbance;
}

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/VertMesh.hlsl"

PackedVaryingsType Vert(AttributesMesh inputMesh)
{
    VaryingsType varyingsType;
    varyingsType.vmesh = VertMesh(inputMesh);
    return PackVaryingsType(varyingsType);
}

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Debug/DebugDisplayMaterial.hlsl"

float GetDeExposureMultiplier()
{
#if defined(DISABLE_UNLIT_DEEXPOSURE)
    return 1.0;
#else
    return _DeExposureMultiplier;
#endif
}

void Frag(PackedVaryingsToPS packedInput,
            out float4 outColor : SV_Target0
           , out float4 momentZero : SV_Target1
           , out float4 accumulatedColor : SV_Target2
        #ifdef _DEPTHOFFSET_ON
            , out float outputDepth : DEPTH_OFFSET_SEMANTIC
        #endif
)
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(packedInput);
    FragInputs input = UnpackVaryingsToFragInputs(packedInput);

    AdjustFragInputsToOffScreenRendering(input, _OffScreenRendering > 0, _OffScreenDownsampleFactor);

    // input.positionSS is SV_Position
    PositionInputs posInput = GetPositionInput(input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionRWS.xyz);

#ifdef VARYINGS_NEED_POSITION_WS
    float3 V = GetWorldSpaceNormalizeViewDir(input.positionRWS);
#else
    // Unused
    float3 V = float3(1.0, 1.0, 1.0); // Avoid the division by 0
#endif

    SurfaceData surfaceData;
    BuiltinData builtinData;
    GetSurfaceAndBuiltinData(input, V, posInput, surfaceData, builtinData);

    // Not lit here (but emissive is allowed)
    BSDFData bsdfData = ConvertSurfaceDataToBSDFData(input.positionSS.xy, surfaceData);

    // If this is a shadow matte, then we want the AO to affect the base color (the AO being correct if the surface is flagged shadow matte).
#if defined(_ENABLE_SHADOW_MATTE)
    bsdfData.color *= GetScreenSpaceAmbientOcclusion(input.positionSS.xy);
#endif

#ifdef DEBUG_DISPLAY
    // Handle debug lighting mode here as there is no lightloop for unlit.
    // For unlit we let all unlit object appear
    if (_DebugLightingMode >= DEBUGLIGHTINGMODE_DIFFUSE_LIGHTING && _DebugLightingMode <= DEBUGLIGHTINGMODE_EMISSIVE_LIGHTING)
    {
        if (_DebugLightingMode != DEBUGLIGHTINGMODE_EMISSIVE_LIGHTING)
        {
            builtinData.emissiveColor = 0.0;
        }
        else
        {
            bsdfData.color = 0.0;
        }
    }
#endif


    float3 finalColor = bsdfData.color * GetDeExposureMultiplier() + builtinData.emissiveColor * GetCurrentExposureMultiplier();
    float4 outResult = ApplyBlendMode(finalColor, builtinData.opacity);
    float b0;
    float4 b;
    generateMoments(posInput.linearDepth, 1 - builtinData.opacity, b0, b);
    outColor = b;
    momentZero = b0;
    accumulatedColor = float4(finalColor.rgb, 1.0); // the alpha of color is the number of overlaping transparent surfaces

    // TODO: combine atmospheric scattering on transparents after as if it's a transparent
    // // Note: we must not access bsdfData in shader pass, but for unlit we make an exception and assume it should have a color field
    // outResult = EvaluateAtmosphericScattering(posInput, V, outResult);

    // outColor = outResult;

#ifdef _DEPTHOFFSET_ON
    outputDepth = posInput.deviceDepth;
#endif
}

// void FragOIT_Resolve(PackedVaryingsToPS packedInput,
//     out float4 outColor : SV_Target0
//    , out float4 momentZero : SV_Target1
// #ifdef _DEPTHOFFSET_ON
//     , out float outputDepth : DEPTH_OFFSET_SEMANTIC
// #endif
// )
// {
// UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(packedInput);
// FragInputs input = UnpackVaryingsToFragInputs(packedInput);

// AdjustFragInputsToOffScreenRendering(input, _OffScreenRendering > 0, _OffScreenDownsampleFactor);

// // input.positionSS is SV_Position
// PositionInputs posInput = GetPositionInput(input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionRWS.xyz);


// #ifdef VARYINGS_NEED_POSITION_WS
// float3 V = GetWorldSpaceNormalizeViewDir(input.positionRWS);
// #else
// // Unused
// float3 V = float3(1.0, 1.0, 1.0); // Avoid the division by 0
// #endif

// SurfaceData surfaceData;
// BuiltinData builtinData;
// GetSurfaceAndBuiltinData(input, V, posInput, surfaceData, builtinData);

// // Not lit here (but emissive is allowed)
// BSDFData bsdfData = ConvertSurfaceDataToBSDFData(input.positionSS.xy, surfaceData);

// // If this is a shadow matte, then we want the AO to affect the base color (the AO being correct if the surface is flagged shadow matte).
// #if defined(_ENABLE_SHADOW_MATTE)
// bsdfData.color *= GetScreenSpaceAmbientOcclusion(input.positionSS.xy);
// #endif

// #ifdef DEBUG_DISPLAY
// // Handle debug lighting mode here as there is no lightloop for unlit.
// // For unlit we let all unlit object appear
// if (_DebugLightingMode >= DEBUGLIGHTINGMODE_DIFFUSE_LIGHTING && _DebugLightingMode <= DEBUGLIGHTINGMODE_EMISSIVE_LIGHTING)
// {
// if (_DebugLightingMode != DEBUGLIGHTINGMODE_EMISSIVE_LIGHTING)
// {
//     builtinData.emissiveColor = 0.0;
// }
// else
// {
//     bsdfData.color = 0.0;
// }
// }
// #endif


// // Sample moment textures

// float4 outResult = ApplyBlendMode(bsdfData.color * GetDeExposureMultiplier() + builtinData.emissiveColor * GetCurrentExposureMultiplier(), builtinData.opacity);
// float b0;
// float4 b;
// generateMoments(builtinData.opacity, outResult, b0, b);
// outColor = b;
// momentZero = b0;

// // TODO: combine atmospheric scattering on transparents after as if it's a transparent
// // // Note: we must not access bsdfData in shader pass, but for unlit we make an exception and assume it should have a color field
// // outResult = EvaluateAtmosphericScattering(posInput, V, outResult);

// // outColor = outResult;

// #ifdef _DEPTHOFFSET_ON
// outputDepth = posInput.deviceDepth;
// #endif
// }

