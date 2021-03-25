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
        if (!render || ctx.hdCamera.camera == bakingCamera || bakingCamera == null || ctx.hdCamera.camera.cameraType == CameraType.SceneView)
            return;
        
        bakingCamera.TryGetCullingParameters(out var cullingParams);

        cullingParams.cullingOptions = CullingOptions.ShadowCasters;

        // Assign the custom culling result to the context
        // so it'll be used for the following operations
        cullingResultField.SetValueDirect(__makeref(ctx), ctx.renderContext.Cull(ref cullingParams));
        var overrideDepthTest = new RenderStateBlock(RenderStateMask.Depth) { depthState = new DepthState(true, CompareFunction.LessEqual) };

        // Sync baking camera aspect ratio with RT (see https://github.com/alelievr/HDRP-Custom-Passes/issues/24)
        bakingCamera.aspect = ctx.hdCamera.camera.aspect;
        bakingCamera.pixelRect = ctx.hdCamera.camera.pixelRect;

        // Depth
        if (depthTexture != null)
        {
            SyncRenderTextureAspect(depthTexture, ctx.hdCamera.camera);
            CoreUtils.SetRenderTarget(ctx.cmd, depthTexture, ClearFlag.Depth);
            CustomPassUtils.RenderDepthFromCamera(ctx, bakingCamera, bakingCamera.cullingMask, overrideRenderState: overrideDepthTest);
        }

        // Normal
        if (normalTexture != null)
        {
            SyncRenderTextureAspect(normalTexture, ctx.hdCamera.camera);
            CoreUtils.SetRenderTarget(ctx.cmd, normalTexture, normalTexture.depthBuffer, ClearFlag.All);
            CustomPassUtils.RenderNormalFromCamera(ctx, bakingCamera, bakingCamera.cullingMask, overrideRenderState: overrideDepthTest);
        }

        // Tangent
        if (tangentTexture != null)
        {
            SyncRenderTextureAspect(tangentTexture, ctx.hdCamera.camera);
            CoreUtils.SetRenderTarget(ctx.cmd, tangentTexture, tangentTexture.depthBuffer, ClearFlag.All);
            CustomPassUtils.RenderTangentFromCamera(ctx, bakingCamera, bakingCamera.cullingMask, overrideRenderState: overrideDepthTest);
        }
        // ctx.hdCamera.camera.pixelRect = oldRect;
    }

    // Resize the render texture to match the aspect ratio of the camera (it avoid stretching issues).
    void SyncRenderTextureAspect(RenderTexture rt, Camera camera)
    {
        float aspect = rt.width / (float)rt.height;

        if (!Mathf.Approximately(aspect, camera.aspect))
        {
            rt.Release();
            rt.width = camera.pixelWidth;
            rt.height = camera.pixelHeight;
            rt.Create();
            // Debug.Log(normalTexture.width + " | " + normalTexture.height);
        }
    }
}