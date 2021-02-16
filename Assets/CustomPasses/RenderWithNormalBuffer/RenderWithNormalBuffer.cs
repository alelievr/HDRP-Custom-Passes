using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

class RenderWithNormalBuffer : CustomPass
{
    public LayerMask layerMask;

    ShaderTagId[] depthPrepassIds;
    ShaderTagId[] forwardIds;

    // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
    // When empty this render pass will render to the active camera render target.
    // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
    // The render pipeline will ensure target setup and clearing happens in an performance manner.
    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        depthPrepassIds = new ShaderTagId[] { new ShaderTagId("DepthForwardOnly"), new ShaderTagId("DepthOnly") };
        forwardIds = new ShaderTagId[] { new ShaderTagId("ForwardOnly"), new ShaderTagId("Forward"), new ShaderTagId("SRPDefaultUnlit") }; 
    }

    protected override void AggregateCullingParameters(ref ScriptableCullingParameters cullingParameters, HDCamera hdCamera)
        => cullingParameters.cullingMask |= (uint)layerMask.value;

    protected override void Execute(CustomPassContext ctx)
    {
        PerObjectData renderConfig = PerObjectData.LightProbe | PerObjectData.Lightmaps | PerObjectData.LightProbeProxyVolume;
        if (ctx.hdCamera.frameSettings.IsEnabled(FrameSettingsField.Shadowmask))
            renderConfig |= PerObjectData.OcclusionProbe | PerObjectData.OcclusionProbeProxyVolume | PerObjectData.ShadowMask;

        // We use a different HDRP shader passes for depth prepass (where we write depth + normal) and forward (were we only write color)
        bool isDepthNormal = injectionPoint == CustomPassInjectionPoint.AfterOpaqueDepthAndNormal;
        var ids = isDepthNormal ? depthPrepassIds : forwardIds;

        var result = new RendererListDesc(ids, ctx.cullingResults, ctx.hdCamera.camera)
        {
            rendererConfiguration = renderConfig,
            renderQueueRange = GetRenderQueueRange(RenderQueueType.AllOpaque),
            sortingCriteria = SortingCriteria.CommonOpaque,
            excludeObjectMotionVectors = false,
            layerMask = layerMask,
        };

        if (isDepthNormal)
        {
            // Bind normal + depth buffer
            CoreUtils.SetRenderTarget(ctx.cmd, ctx.cameraNormalBuffer, ctx.cameraDepthBuffer, ClearFlag.None);

            // Enable keyword to write normal in the depth pre-pass
            CoreUtils.SetKeyword(ctx.cmd, "WRITE_NORMAL_BUFFER", true);
        }

        // Render all the opaque objects in the layer
        CoreUtils.DrawRendererList(ctx.renderContext, ctx.cmd, RendererList.Create(result));

        if (isDepthNormal)
        {
            // Reset the keyword to it's default value
            CoreUtils.SetKeyword(ctx.cmd, "WRITE_NORMAL_BUFFER", ctx.hdCamera.frameSettings.litShaderMode == LitShaderMode.Forward);
        }
    }

    protected override void Cleanup()
    {
        // Cleanup code
    }
}