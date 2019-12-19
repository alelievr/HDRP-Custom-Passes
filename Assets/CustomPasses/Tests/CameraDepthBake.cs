using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

class CameraDepthBake : CustomPass
{
    public Camera           bakingCamera = null;
    public RenderTexture    targetTexture = null;
    public bool             render = true;
    ShaderTagId[]           shaderTags;

    // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
    // When empty this render pass will render to the active camera render target.
    // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
    // The render pipeline will ensure target setup and clearing happens in an performance manner.
    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        shaderTags = new ShaderTagId[2]
        {
            new ShaderTagId("DepthOnly"),
            new ShaderTagId("DepthForwardOnly"),
        };
    }

    protected override void Execute(ScriptableRenderContext renderContext, CommandBuffer cmd, HDCamera camera, CullingResults cullingResult)
    {
        // if (!render || camera.camera == bakingCamera)
        //     return;
        
        bakingCamera.TryGetCullingParameters(out var cullingParams);
        cullingParams.cullingOptions = CullingOptions.ShadowCasters;
        cullingResult = renderContext.Cull(ref cullingParams);

        var result = new RendererListDesc(shaderTags, cullingResult, bakingCamera)
        {
            rendererConfiguration = PerObjectData.None,
            renderQueueRange = RenderQueueRange.all,
            sortingCriteria = SortingCriteria.BackToFront,
            excludeObjectMotionVectors = false,
            layerMask = -1,
        };

        var p = GL.GetGPUProjectionMatrix(bakingCamera.projectionMatrix, true);
        Matrix4x4 scaleMatrix = Matrix4x4.identity;
        scaleMatrix.m22 = -1.0f;
        var v = scaleMatrix * bakingCamera.transform.localToWorldMatrix.inverse;
        var vp = p * v;
        cmd.SetGlobalMatrix("_ViewMatrix", v);
        cmd.SetGlobalMatrix("_InvViewMatrix", v.inverse);
        cmd.SetGlobalMatrix("_ProjMatrix", p);
        cmd.SetGlobalMatrix("_InvProjMatrix", p.inverse);
        cmd.SetGlobalMatrix("_ViewProjMatrix", vp);
        cmd.SetGlobalMatrix("_InvViewProjMatrix", vp.inverse);
        cmd.SetGlobalMatrix("_CameraViewProjMatrix", vp);
        cmd.SetGlobalVector("_WorldSpaceCameraPos", Vector3.zero);

        CoreUtils.SetRenderTarget(cmd, targetTexture, ClearFlag.Depth);
        HDUtils.DrawRendererList(renderContext, cmd, RendererList.Create(result));
    }

    protected override void Cleanup()
    {
        // Cleanup code
    }
}