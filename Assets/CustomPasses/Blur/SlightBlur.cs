using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Profiling;

class SlightBlur : CustomPass
{
    [Range(0, 8)]
    public float        radius = 4;
    public bool         useMask = false;
    public LayerMask    maskLayer = 0;
    public bool         invertMask = false;

    [SerializeField]
    Shader          blurCompositeShader;

    Material        blurMaterial;
    Material        compositeMaterial;
    RTHandle        downSampleBuffer;
    RTHandle        maskBuffer;
    RTHandle        maskDepthBuffer;
    RTHandle        colorCopy;

    static class ShaderID
    {
        public static readonly int _BlitTexture = Shader.PropertyToID("_BlitTexture");
        public static readonly int _BlitScaleBias = Shader.PropertyToID("_BlitScaleBias");
        public static readonly int _BlitMipLevel = Shader.PropertyToID("_BlitMipLevel");
        public static readonly int _Radius = Shader.PropertyToID("_Radius");
        public static readonly int _Source = Shader.PropertyToID("_Source");
        public static readonly int _ColorBufferCopy = Shader.PropertyToID("_ColorBufferCopy");
        public static readonly int _Mask = Shader.PropertyToID("_Mask");
        public static readonly int _MaskDepth = Shader.PropertyToID("_MaskDepth");
        public static readonly int _InvertMask = Shader.PropertyToID("_InvertMask");
        public static readonly int _ViewPortSize = Shader.PropertyToID("_ViewPortSize");
    }

    // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
    // When empty this render pass will render to the active camera render target.
    // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
    // The render pipeline will ensure target setup and clearing happens in an performance manner.
    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        blurCompositeShader = Shader.Find("Hidden/Fullscreen/CompositeBlur");
        compositeMaterial = CoreUtils.CreateEngineMaterial(blurCompositeShader);

        // Allocate the buffers used for the blur in half resolution to save some memory
        downSampleBuffer = RTHandles.Alloc(
            Vector2.one * 0.5f, TextureXR.slices, dimension: TextureXR.dimension,
            colorFormat: GraphicsFormat.B10G11R11_UFloatPack32, // We don't need alpha in the blur
            useDynamicScale: true, name: "DownSampleBuffer"
        );
    }

    // TODO: refactor this with stencil bits
    void AllocateMaskBuffersIfNeeded()
    {
        if (useMask)
        {
            if (colorCopy == null)
            {
                var hdrpAsset = (GraphicsSettings.renderPipelineAsset as HDRenderPipelineAsset);
                var colorBufferFormat = hdrpAsset.currentPlatformRenderPipelineSettings.colorBufferFormat;

                colorCopy = RTHandles.Alloc(
                    Vector2.one, TextureXR.slices, dimension: TextureXR.dimension,
                    colorFormat: (GraphicsFormat)colorBufferFormat,
                    useDynamicScale: true, name: "Color Copy"
                );
            }
            if (maskBuffer == null)
            {
                maskBuffer = RTHandles.Alloc(
                    Vector2.one, TextureXR.slices, dimension: TextureXR.dimension,
                    colorFormat: GraphicsFormat.R8_UNorm, // We only need a 1 channel mask to composite the blur and color buffer copy
                    useDynamicScale: true, name: "Blur Mask"
                );
            }
            if (maskDepthBuffer == null)
            {
                maskDepthBuffer = RTHandles.Alloc(
                    Vector2.one, TextureXR.slices, dimension: TextureXR.dimension,
                    colorFormat: GraphicsFormat.R16_UInt, useDynamicScale: true,
                    name: "Blur Depth Mask", depthBufferBits: DepthBits.Depth16
                );
            }
        }
    }

    protected override void AggregateCullingParameters(ref ScriptableCullingParameters cullingParameters, HDCamera hdCamera)
        => cullingParameters.cullingMask |= (uint)maskLayer.value;

    protected override void Execute(CustomPassContext ctx)
    {
        if (radius <= 0)
            return;

        if (useMask && compositeMaterial != null)
        {
            AllocateMaskBuffersIfNeeded();

            var depthStencilOverride = new RenderStateBlock(RenderStateMask.Depth)
            {
                depthState = new DepthState(false, CompareFunction.LessEqual),
                stencilState = new StencilState(true, writeMask: (byte)UserStencilUsage.UserBit0, compareFunction: CompareFunction.Always),
            };
            CoreUtils.SetRenderTarget(ctx.cmd, maskBuffer, ctx.cameraDepthBuffer, ClearFlag.All);
            CustomPassUtils.DrawRenderers(ctx, maskLayer, overrideRenderState: depthStencilOverride);

            CustomPassUtils.GaussianBlur(ctx, ctx.cameraColorBuffer, colorCopy, downSampleBuffer, sampleCount: 15, radius: radius, downSample: true);

            ComposeMaskedBlur(ctx);
        }
        else
        {
            CustomPassUtils.GaussianBlur(ctx, ctx.cameraColorBuffer, ctx.cameraColorBuffer, downSampleBuffer, sampleCount: 15, radius: radius, downSample: true);
        }
    }

    void ComposeMaskedBlur(CustomPassContext ctx)
    {
        ctx.propertyBlock.SetTexture(ShaderID._Source, colorCopy);
        ctx.propertyBlock.SetTexture(ShaderID._ColorBufferCopy, colorCopy);
        ctx.propertyBlock.SetTexture(ShaderID._Mask, maskBuffer);
        ctx.propertyBlock.SetTexture(ShaderID._MaskDepth, maskDepthBuffer);
        ctx.propertyBlock.SetFloat(ShaderID._InvertMask, invertMask ? 1 : 0);

        CustomPassUtils.FullScreenPass(ctx, compositeMaterial, 0, ctx.cameraColorBuffer);
    }

    // release all resources
    protected override void Cleanup()
    {
        CoreUtils.Destroy(compositeMaterial);
        downSampleBuffer.Release();
        maskDepthBuffer?.Release();
        maskBuffer?.Release();
        colorCopy?.Release();
    }
}