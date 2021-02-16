using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using System.Reflection;

class CameraDepthBake : CustomPass
{
    public Camera           bakingCamera = null;
    public RenderTexture    depthTexture = null;
    public RenderTexture    normalTexture = null;
    public RenderTexture    tangentTexture = null;
    public bool             render = true;

    FieldInfo cullingResultField;

    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        // Temporary hack for culling override in HDRP 10.x
        cullingResultField = typeof(CustomPassContext).GetField(nameof(CustomPassContext.cullingResults));
    }

    protected override void Execute(CustomPassContext ctx)
    {
        if (!render || ctx.hdCamera.camera == bakingCamera || bakingCamera == null)
            return;
        
        bakingCamera.TryGetCullingParameters(out var cullingParams);

        cullingParams.cullingOptions = CullingOptions.ShadowCasters;

        // Assign the custom culling result to the context
        // so it'll be used for the following operations
        cullingResultField.SetValueDirect(__makeref(ctx), ctx.renderContext.Cull(ref cullingParams));

        // Depth
        if (depthTexture != null)
        {
            var overrideDepthTest = new RenderStateBlock(RenderStateMask.Depth) { depthState = new DepthState(true, CompareFunction.LessEqual) };
            CoreUtils.SetRenderTarget(ctx.cmd, depthTexture, ClearFlag.Depth);
            CustomPassUtils.RenderDepthFromCamera(ctx, bakingCamera, bakingCamera.cullingMask, overrideRenderState: overrideDepthTest);
        }

        // Normal
        if (normalTexture != null)
        {
            CoreUtils.SetRenderTarget(ctx.cmd, normalTexture, normalTexture.depthBuffer, ClearFlag.Depth);
            CustomPassUtils.RenderNormalFromCamera(ctx, bakingCamera, bakingCamera.cullingMask);
        }

        // Tangent
        if (tangentTexture != null)
        {
            CoreUtils.SetRenderTarget(ctx.cmd, tangentTexture, tangentTexture.depthBuffer, ClearFlag.Depth);
            CustomPassUtils.RenderTangentFromCamera(ctx, bakingCamera, bakingCamera.cullingMask);
        }
    }
}