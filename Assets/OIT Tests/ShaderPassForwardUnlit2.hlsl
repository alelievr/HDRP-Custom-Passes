#if SHADERPASS != SHADERPASS_FORWARD_UNLIT
#error SHADERPASS_is_not_correctly_define
#endif

#include "MBOIT.hlsl"

TEXTURE2D_X(_MomentOIT);
TEXTURE2D_X(_MomentZeroOIT);

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/VertMesh.hlsl"

PackedVaryingsType Vert(AttributesMesh inputMesh)
{
    VaryingsType varyingsType;
    varyingsType.vmesh = VertMesh(inputMesh);
    return PackVaryingsType(varyingsType);
}

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Debug/DebugDisplayMaterial.hlsl"

float RemapDepth(float linearDepth)
{
    float depth01 = linearDepth / 1000;
    return depth01 * 2 - 1; // depth between -1 and 1 
}

void Frag(PackedVaryingsToPS packedInput,
            out float4 moments : SV_Target0
           , out float4 momentZero : SV_Target1
           , out float4 accumulatedColor : SV_Target2
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

    float3 finalColor = bsdfData.color + builtinData.emissiveColor * GetCurrentExposureMultiplier();
    float4 outResult = ApplyBlendMode(finalColor, builtinData.opacity);
    float b0;
    float4 b;
    generateMoments(RemapDepth(posInput.linearDepth), 1 - builtinData.opacity, b0, b);
    moments = b;
    momentZero = b0;
    accumulatedColor = float4(finalColor.rgb, 1.0); // the alpha of color is the number of overlaping transparent surfaces

    // TODO: combine atmospheric scattering on transparents after as if it's a transparent
    // // Note: we must not access bsdfData in shader pass, but for unlit we make an exception and assume it should have a color field
    // outResult = EvaluateAtmosphericScattering(posInput, V, outResult);

    // outColor = outResult;
}

void FragOIT_Resolve(PackedVaryingsToPS packedInput,
    out float4 outColor : SV_Target0
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
    
    // Sample moment textures
    float4 momentData = LOAD_TEXTURE2D_X(_MomentOIT, posInput.positionSS);
    float zerothMoment = LOAD_TEXTURE2D_X(_MomentZeroOIT, posInput.positionSS).x;

    if (zerothMoment == 0)
    {
        outColor = 0;
    }
    else
    {
        // Reconstruct transmittance from the moments using depth and moments (section 3.2)
        float transmittanceAtDepth, totalTransmittance;
        resolveMoments(transmittanceAtDepth, totalTransmittance, RemapDepth(posInput.linearDepth), zerothMoment, momentData);
    
        outColor = float4(bsdfData.color * builtinData.opacity * transmittanceAtDepth, 1);
    }
}

