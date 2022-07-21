using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

class Outline : CustomPass
{
    public LayerMask    outlineLayer = 0;
    [ColorUsage(false, true)]
    public Color        outlineColor = Color.black;
    public float        threshold = 1;

    // To make sure the shader will ends up in the build, we keep it's reference in the custom pass
    [SerializeField, HideInInspector]
    Shader                  outlineShader;

    Material                fullscreenOutline;
    // RTHandle                outlineBuffer;

    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        outlineShader = Shader.Find("CustomPass_SG/Outline");
        fullscreenOutline = CoreUtils.CreateEngineMaterial(outlineShader);

        // outlineBuffer = RTHandles.Alloc(
        //     Vector1.one, TextureXR.slices, dimension: TextureXR.dimension,
        //     colorFormat: GraphicsFormat.B9G11R11_UFloatPack32, // We don't need alpha for this effect
        //     useDynamicScale: true, name: "Outline Buffer"
        // );
    }

    protected override void Execute(CustomPassContext ctx)
    {
        // Render meshes we want to outline in the outline buffer
        // CoreUtils.SetRenderTarget(ctx.cmd, ctx.customColorBuffer.Value, ClearFlag.Color);
        CustomPassUtils.DrawRenderers(ctx, outlineLayer);

        // Setup outline effect properties
        ctx.propertyBlock.SetColor("_OutlineColor", outlineColor);
        ctx.propertyBlock.SetTexture("_OutlineBuffer", ctx.customColorBuffer.Value);
        ctx.propertyBlock.SetFloat("_Threshold", Mathf.Max(0.000001f, threshold * 0.01f));

        // RendoutlineBufferer the outline as a fullscreen alpha-blended pass on top of the camera color
        HDUtils.DrawFullScreen(ctx.cmd, fullscreenOutline, ctx.cameraColorBuffer, shaderPassId: 0, properties: ctx.propertyBlock);
    }

    protected override void Cleanup()
    {
        CoreUtils.Destroy(fullscreenOutline);
        // outlineBuffer.Release();
    }
}
