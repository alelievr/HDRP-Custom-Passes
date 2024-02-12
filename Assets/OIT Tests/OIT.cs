using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;
using static Unity.Mathematics.math;

class OIT : CustomPass
{
    public LayerMask transparentLayerMask;
    public Material resolveMomentOITMaterial;
    public Material transparentFogMaterial;

    public float overEstimation;

    RTHandle momentOIT;
    RTHandle accumulatedColor;
    RTHandle momentZeroOIT;
    RTHandle resolvedMoments;

    ShaderTagId unlitForwardTagId;
    ShaderTagId unlitForwardOITTagId;

    protected override void AggregateCullingParameters(ref ScriptableCullingParameters cullingParameters, HDCamera hdCamera)
    {
        cullingParameters.cullingMask |= (uint)transparentLayerMask.value;
    }

    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        var fmt = GraphicsFormat.R32G32B32A32_SFloat;
        momentOIT = RTHandles.Alloc(Vector2.one, TextureXR.slices, dimension: TextureXR.dimension, colorFormat: fmt, useMipMap: false, autoGenerateMips: false, name: "MomentOIT");
        momentZeroOIT = RTHandles.Alloc(Vector2.one, TextureXR.slices, dimension: TextureXR.dimension, colorFormat: fmt, useMipMap: false, autoGenerateMips: false, name: "MomentZeroOIT");
        accumulatedColor = RTHandles.Alloc(Vector2.one, TextureXR.slices, dimension: TextureXR.dimension, colorFormat: fmt, useMipMap: false, autoGenerateMips: false, name: "AccumulatedColorOIT");
        resolvedMoments = RTHandles.Alloc(Vector2.one, TextureXR.slices, dimension: TextureXR.dimension, colorFormat: fmt, useMipMap: false, autoGenerateMips: false, name: "ResolvedMoments");
        unlitForwardTagId = new ShaderTagId("ForwardOnly");
        unlitForwardOITTagId = new ShaderTagId("ForwardOnly_OIT");
    }

    protected override void Execute(CustomPassContext ctx)
    {
        if (resolveMomentOITMaterial == null)
            return;

        // Implementation of MBOIT: https://momentsingraphics.de/Media/I3D2018/Muenstermann2018-MBOIT.pdf
        // Using 4 power moments and 16 bit quantization: https://momentsingraphics.de/Media/I3D2018/Muenstermann2018-MBOITSupplementary.pdf

        // Update global constants:
        Shader.SetGlobalVector("wrapping_zone_parameters", Vector4.zero); // required for trigonometric moment s we don't need it
        Shader.SetGlobalFloat("overestimation", overEstimation); // This value probably works well
        Shader.SetGlobalFloat("moment_bias", 6e-5f);
        Shader.SetGlobalFloat("_DepthDistance", ctx.hdCamera.camera.farClipPlane - ctx.hdCamera.camera.nearClipPlane);

        // Render moment and moment zero into the 2 RTs using the transparent depth and transmittance values (section 3.1)
        CoreUtils.SetRenderTarget(ctx.cmd, new RenderTargetIdentifier[]{ momentOIT, momentZeroOIT, accumulatedColor }, ctx.cameraDepthBuffer, ClearFlag.Color, Color.clear);
        CustomPassUtils.DrawRenderers(ctx, new ShaderTagId[]{ unlitForwardTagId }, transparentLayerMask);
        if (transparentFogMaterial != null)
            CoreUtils.DrawFullScreen(ctx.cmd, transparentFogMaterial, shaderPassId: 0);

        // Render transparent objects color (standard shading) and reconstruct the transmittance using the moment buffers (section 3.2)
        ctx.cmd.SetGlobalTexture("_MomentOIT", momentOIT);
        ctx.cmd.SetGlobalTexture("_MomentZeroOIT", momentZeroOIT);
        CoreUtils.SetRenderTarget(ctx.cmd, resolvedMoments, ctx.cameraDepthBuffer, ClearFlag.Color);
        CustomPassUtils.DrawRenderers(ctx, new ShaderTagId[]{ unlitForwardOITTagId }, transparentLayerMask);
        if (transparentFogMaterial != null)
            CoreUtils.DrawFullScreen(ctx.cmd, transparentFogMaterial, shaderPassId: 1);

        var props = new MaterialPropertyBlock(); 
        props.SetTexture("_MomentOIT", momentOIT);
        props.SetTexture("_MomentZeroOIT", momentZeroOIT);
        // props.SetTexture("_AccumulatedColorOIT", accumulatedColor);
        props.SetTexture("_ResolvedMoments", resolvedMoments);
        HDUtils.DrawFullScreen(ctx.cmd, resolveMomentOITMaterial, ctx.cameraColorBuffer, props);
    }

    protected override void Cleanup()
    {
        momentOIT.Release();
        momentZeroOIT.Release();
        accumulatedColor.Release();
        resolvedMoments.Release();
    }
}