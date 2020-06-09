using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

class ExtractBuffers : CustomPass
{
    public RenderTexture normalRT;
    public RenderTexture depthRT;

    Material extractMat;

    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        extractMat = CoreUtils.CreateEngineMaterial("FullScreen/ExtractBuffers");
    }

    protected override void Execute(CustomPassContext ctx)
    {
        if (ctx.hdCamera.camera.cameraType == CameraType.Game)
        {
            CoreUtils.SetRenderTarget(ctx.cmd, new RenderTargetIdentifier[] { normalRT, depthRT }, normalRT.depthBuffer);
            CoreUtils.DrawFullScreen(ctx.cmd, extractMat);
        }
    }

    protected override void Cleanup()
    {
        CoreUtils.Destroy(extractMat);
    }
}