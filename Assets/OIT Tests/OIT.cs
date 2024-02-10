using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

class OIT : CustomPass
{
    public LayerMask transparentLayerMask;
    public Material resolveMomentOITMaterial;

    RTHandle momentOIT;
    RTHandle accumulatedColor;
    RTHandle momentZeroOIT;

    ShaderTagId unlitForwardTagId;
    // ShaderTagId unlitForwardOITTagId = new ShaderTagId("ForwardOnly_OIT");

    protected override void AggregateCullingParameters(ref ScriptableCullingParameters cullingParameters, HDCamera hdCamera)
    {
        cullingParameters.cullingMask |= (uint)transparentLayerMask.value;
    }

    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        momentOIT = RTHandles.Alloc(Vector2.one, TextureXR.slices, dimension: TextureXR.dimension, colorFormat: GraphicsFormat.R16G16B16A16_SFloat, useMipMap: false, autoGenerateMips: false, name: "MomentOIT");
        momentZeroOIT = RTHandles.Alloc(Vector2.one, TextureXR.slices, dimension: TextureXR.dimension, colorFormat: GraphicsFormat.R16G16B16A16_SFloat, useMipMap: false, autoGenerateMips: false, name: "MomentZeroOIT");
        accumulatedColor = RTHandles.Alloc(Vector2.one, TextureXR.slices, dimension: TextureXR.dimension, colorFormat: GraphicsFormat.R16G16B16A16_SFloat, useMipMap: false, autoGenerateMips: false, name: "AccumulatedColorOIT");
        unlitForwardTagId = new ShaderTagId("ForwardOnly");
    }

    protected override void Execute(CustomPassContext ctx)
    {
        CoreUtils.SetRenderTarget(ctx.cmd, new RenderTargetIdentifier[]{ momentOIT, momentZeroOIT, accumulatedColor }, ctx.cameraDepthBuffer, ClearFlag.All, Color.clear);
        // Render moment and moment zero into the 2 RTs
        CustomPassUtils.DrawRenderers(ctx, new ShaderTagId[]{ unlitForwardTagId }, transparentLayerMask);
        // CoreUtils.SetRenderTarget(ctx.cmd, ctx.cameraColorBuffer, ctx.cameraDepthBuffer);
        // ctx.cmd.SetGlobalTexture("_MomentOIT", momentOIT);
        // ctx.cmd.SetGlobalTexture("_MomentZeroOIT", momentZeroOIT);

        // // Re-render the transparent objects again to accumulate the color
        // CustomPassUtils.DrawRenderers(ctx, new ShaderTagId[]{ unlitForwardOITTagId }, transparentLayerMask);

        var props = new MaterialPropertyBlock(); 
        props.SetTexture("_MomentOIT", momentOIT);
        props.SetTexture("_MomentZeroOIT", momentZeroOIT);
        props.SetTexture("_AccumulatedColorOIT", accumulatedColor);
        HDUtils.DrawFullScreen(ctx.cmd, resolveMomentOITMaterial, ctx.cameraColorBuffer, props);
    }

    protected override void Cleanup()
    {
        momentOIT.Release();
        momentZeroOIT.Release();
        accumulatedColor.Release();
    }
}