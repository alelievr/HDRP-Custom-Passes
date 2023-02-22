using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering.RendererUtils;

#if UNITY_EDITOR
using UnityEditor.Rendering.HighDefinition;

[CustomPassDrawerAttribute(typeof(RenderMotionVectors))]
class RenderMotionVectorsEditor : CustomPassDrawer
{
    protected override PassUIFlag commonPassUIFlags => PassUIFlag.Name;
}
#endif

class RenderMotionVectors : CustomPass
{
    public RenderTexture motionVectorTexture;
    public LayerMask renderingMask = -1;

    protected override bool executeInSceneView => false;

    RenderTexture dummy;

    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        dummy = new RenderTexture(1, 1, 24, GraphicsFormat.R8_SNorm);
        dummy.Create();
        // Setup code here
    }

    protected override void Execute(CustomPassContext ctx)
    {
        if (!ctx.hdCamera.frameSettings.IsEnabled(FrameSettingsField.ObjectMotionVectors) ||
            !ctx.hdCamera.frameSettings.IsEnabled(FrameSettingsField.OpaqueObjects))
        {
            Debug.Log("Motion Vectors are disabled on the camera!");
            return;
        }

        SyncRenderTextureAspect(motionVectorTexture, ctx.hdCamera.camera);

        var tags = new ShaderTagId("MotionVectors");
        var motionVectorRendererListDesc = new RendererListDesc(tags, ctx.cullingResults, ctx.hdCamera.camera)
        {
            rendererConfiguration = PerObjectData.MotionVectors,
            renderQueueRange = RenderQueueRange.all,
            sortingCriteria = SortingCriteria.BackToFront,
            excludeObjectMotionVectors = false,
            layerMask = renderingMask
        };

        if (ctx.hdCamera.msaaSamples != MSAASamples.None)
            CoreUtils.SetRenderTarget(ctx.cmd, new RenderTargetIdentifier[]{ dummy.colorBuffer, motionVectorTexture }, dummy.depthBuffer, ClearFlag.All);
        else
            CoreUtils.SetRenderTarget(ctx.cmd, new RenderTargetIdentifier[]{ motionVectorTexture }, motionVectorTexture.depthBuffer, ClearFlag.All);
        CoreUtils.DrawRendererList(ctx.renderContext, ctx.cmd, ctx.renderContext.CreateRendererList(motionVectorRendererListDesc));
    }

    void SyncRenderTextureAspect(RenderTexture rt, Camera camera)
    {
        float aspect = rt.width / (float)rt.height;

        if (!Mathf.Approximately(aspect, camera.aspect))
        {
            rt.Release();
            rt.width = camera.pixelWidth;
            rt.height = camera.pixelHeight;
            rt.Create();

            dummy.Release();
            dummy.width = camera.pixelWidth;
            dummy.height = camera.pixelHeight;
            dummy.Create();
        }
    }

    protected override void Cleanup()
    {
        dummy.Release();
    }
}