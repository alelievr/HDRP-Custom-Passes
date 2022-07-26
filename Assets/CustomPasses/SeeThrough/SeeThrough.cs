using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;
using System.Collections.Generic;

class SeeThrough : CustomPass
{
    public LayerMask seeThroughLayer = 1;
    public Material seeThroughMaterial = null;

    [SerializeField, HideInInspector]
    Shader stencilShader;

    Material stencilMaterial;

    ShaderTagId[]   shaderTags;

    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        if (stencilShader == null)
            stencilShader = Shader.Find("Hidden/Renderers/SeeThroughStencil");

        stencilMaterial = CoreUtils.CreateEngineMaterial(stencilShader);

        shaderTags = new ShaderTagId[4]
        {
            new ShaderTagId("Forward"),
            new ShaderTagId("ForwardOnly"),
            new ShaderTagId("SRPDefaultUnlit"),
            new ShaderTagId("FirstPass"),
        };
    }

    protected override void Execute(CustomPassContext ctx)
    {
        // We first render objects into the user stencil bit 0, this will allow us to detect
        // if the object is behind another object.
        stencilMaterial.SetInt("_StencilWriteMask", (int)UserStencilUsage.UserBit0);

        RenderObjects(ctx.renderContext, ctx.cmd, stencilMaterial, 0, CompareFunction.LessEqual, ctx.cullingResults, ctx.hdCamera);
        // CustomPassUtils.DrawRenderers(ctx, seeThroughLayer, RenderQueueType.All, overrideRenderState: stencilWriteRenderState);

        // Then we render the objects that are behind walls using the stencil buffer with Greater Equal ZTest:
        StencilState seeThroughStencil = new StencilState(
            enabled: true,
            readMask: (byte)UserStencilUsage.UserBit0,
            compareFunction: CompareFunction.Equal
        );
        RenderObjects(ctx.renderContext, ctx.cmd, seeThroughMaterial, seeThroughMaterial.FindPass("ForwardOnly"), CompareFunction.GreaterEqual, ctx.cullingResults, ctx.hdCamera, seeThroughStencil);
    }

    public override IEnumerable<Material> RegisterMaterialForInspector() { yield return seeThroughMaterial; }

    void RenderObjects(ScriptableRenderContext renderContext, CommandBuffer cmd, Material overrideMaterial, int passIndex, CompareFunction depthCompare, CullingResults cullingResult, HDCamera hdCamera, StencilState? overrideStencil = null)
    {
        // Render the objects in the layer blur mask into a mask buffer with their materials so we keep the alpha-clip and transparency if there is any.
        var result = new UnityEngine.Rendering.RendererUtils.RendererListDesc(shaderTags, cullingResult, hdCamera.camera)
        {
            rendererConfiguration = PerObjectData.None,
            renderQueueRange = RenderQueueRange.all,
            sortingCriteria = SortingCriteria.BackToFront,
            excludeObjectMotionVectors = false,
            overrideMaterial = overrideMaterial,
            overrideMaterialPassIndex = passIndex,
            layerMask = seeThroughLayer,
            stateBlock = new RenderStateBlock(RenderStateMask.Depth){ depthState = new DepthState(true, depthCompare)},
        };

        if (overrideStencil != null)
        {
            var block = result.stateBlock.Value;
            block.mask |= RenderStateMask.Stencil;
            block.stencilState = overrideStencil.Value;
            result.stateBlock = block;
        }

        CoreUtils.DrawRendererList(renderContext, cmd, renderContext.CreateRendererList(result));
    }

    protected override void Cleanup()
    {
        // Cleanup code
    }
}