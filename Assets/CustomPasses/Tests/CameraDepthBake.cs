using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

class CameraDepthBake : CustomPass
{
    public Camera           bakingCamera = null;
    public RenderTexture    depthTexture = null;
    public RenderTexture    normalTexture = null;
    public RenderTexture    tangentTexture = null;
    public bool             render = true;

    protected override void Execute(CustomPassContext ctx)
    {
        if (!render || ctx.hdCamera.camera == bakingCamera)
            return;

        bakingCamera.TryGetCullingParameters(out var cullingParams);
        cullingParams.cullingOptions = CullingOptions.ShadowCasters;

        // Assign the custom culling result to the context
        // so it'll be used for the following operations
        ctx.cullingResults = ctx.renderContext.Cull(ref cullingParams);

        // Depth
        CoreUtils.SetRenderTarget(ctx.cmd, depthTexture, ClearFlag.Depth);
        CustomPassUtils.RenderDepthFromCamera(ctx, bakingCamera, bakingCamera.cullingMask);

        // Normal
        CoreUtils.SetRenderTarget(ctx.cmd, normalTexture, normalTexture.depthBuffer, ClearFlag.Depth);
        CustomPassUtils.RenderNormalFromCamera(ctx, bakingCamera, bakingCamera.cullingMask);

        // Tangent
        CoreUtils.SetRenderTarget(ctx.cmd, tangentTexture, tangentTexture.depthBuffer, ClearFlag.Depth);
        CustomPassUtils.RenderTangentFromCamera(ctx, bakingCamera, bakingCamera.cullingMask);
    }
}