using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Profiling;

class SlightBlur : CustomPass
{
    [Range(0, 16)]
    public float        radius = 4;
    public bool         useMask = false;
    public LayerMask    maskLayer = 0;
    public bool         invertMask = false;

    Material        compositeMaterial;
    Material        whiteRenderersMaterial;
    RTHandle        downSampleBuffer;
    RTHandle        blurBuffer;
    RTHandle        maskBuffer;
    RTHandle        maskDepthBuffer;
    RTHandle        colorCopy;
    ShaderTagId[]   shaderTags;

    // Trick to always include these shaders in build
    [SerializeField, HideInInspector]
    Shader compositeShader;
    [SerializeField, HideInInspector]
    Shader whiteRenderersShader;

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
        if (compositeShader == null)
            compositeShader = Resources.Load<Shader>("CompositeBlur");
        if (whiteRenderersShader == null)
            whiteRenderersShader = Shader.Find("Hidden/Renderers/WhiteRenderers");

        compositeMaterial = CoreUtils.CreateEngineMaterial(compositeShader);
        whiteRenderersMaterial = CoreUtils.CreateEngineMaterial(whiteRenderersShader);

        // Allocate the buffers used for the blur in half resolution to save some memory
        downSampleBuffer = RTHandles.Alloc(
            Vector2.one * 0.5f, TextureXR.slices, dimension: TextureXR.dimension,
            colorFormat: GraphicsFormat.B10G11R11_UFloatPack32, // We don't need alpha in the blur
            useDynamicScale: true, name: "DownSampleBuffer"
        );
        
        blurBuffer = RTHandles.Alloc(
            Vector2.one * 0.5f, TextureXR.slices, dimension: TextureXR.dimension,
            colorFormat: GraphicsFormat.B10G11R11_UFloatPack32, // We don't need alpha in the blur
            useDynamicScale: true, name: "BlurBuffer"
        );

        shaderTags = new ShaderTagId[4]
        {
            new ShaderTagId("Forward"),
            new ShaderTagId("ForwardOnly"),
            new ShaderTagId("SRPDefaultUnlit"),
            new ShaderTagId("FirstPass"),
        };
    }

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

    protected override void Execute(CustomPassContext ctx)
    {
        AllocateMaskBuffersIfNeeded();

        if (compositeMaterial != null && radius > 0)
        {
            if (useMask)
            {
                CoreUtils.SetRenderTarget(ctx.cmd, maskBuffer, maskDepthBuffer, ClearFlag.All);
                CustomPassUtils.DrawRenderers(ctx, maskLayer, overrideRenderState: new RenderStateBlock(RenderStateMask.Depth){ depthState = new DepthState(true, CompareFunction.LessEqual)});
                // DrawMaskObjects(renderContext, cmd, hdCamera, cullingResult);
            }

            GenerateGaussianMips(ctx);
        }
    }

    protected override void AggregateCullingParameters(ref ScriptableCullingParameters cullingParameters, HDCamera hdCamera)
        => cullingParameters.cullingMask |= (uint)maskLayer.value;

    // void DrawMaskObjects(ScriptableRenderContext renderContext, CommandBuffer cmd, HDCamera hdCamera, CullingResults cullingResult)
    // {
    //     // Render the objects in the layer blur mask into a mask buffer with their materials so we keep the alpha-clip and transparency if there is any.
    //     var result = new RendererListDesc(shaderTags, cullingResult, hdCamera.camera)
    //     {
    //         rendererConfiguration = PerObjectData.None,
    //         renderQueueRange = RenderQueueRange.all,
    //         sortingCriteria = SortingCriteria.BackToFront,
    //         excludeObjectMotionVectors = false,
    //         layerMask = maskLayer,
    //         stateBlock = ,
    //     };

    //     CoreUtils.SetRenderTarget(cmd, maskBuffer, maskDepthBuffer, ClearFlag.All);
    //     HDUtils.DrawRendererList(renderContext, cmd, RendererList.Create(result));
    // }

    // We need the viewport size in our shader because we're using half resolution render targets (and so the _ScreenSize
    // variable in the shader does not match the viewport).
    void SetViewPortSize(CommandBuffer cmd, MaterialPropertyBlock block, RTHandle target)
    {
        Vector2Int scaledViewportSize = target.GetScaledSize(target.rtHandleProperties.currentViewportSize);
        block.SetVector(ShaderID._ViewPortSize, new Vector4(scaledViewportSize.x, scaledViewportSize.y, 1.0f / (float)scaledViewportSize.x, 1.0f / (float)scaledViewportSize.y));
    }

    void GenerateGaussianMips(CustomPassContext ctx)
    {
        RTHandle source = (targetColorBuffer == TargetBuffer.Camera) ? ctx.cameraColorBuffer : ctx.customColorBuffer.Value;

        // Save the non blurred color into a copy if the mask is enabled:
        if (useMask)
            ctx.cmd.CopyTexture(source, colorCopy);

        var targetBuffer = (useMask) ? downSampleBuffer : source; 
        CustomPassUtils.GaussianBlur(ctx, source, targetBuffer, blurBuffer, radius: radius);

        if (useMask)
        {
            // Merge the non blur copy and the blurred version using the mask buffers
            using (new ProfilingScope(ctx.cmd, new ProfilingSampler("Compose Mask Blur")))
            {
                var compositingProperties = new MaterialPropertyBlock();

                compositingProperties.SetFloat(ShaderID._Radius, radius / 4f); // The blur is 4 pixel wide in the shader
                compositingProperties.SetTexture(ShaderID._Source, downSampleBuffer);
                compositingProperties.SetTexture(ShaderID._ColorBufferCopy, colorCopy);
                compositingProperties.SetTexture(ShaderID._Mask, maskBuffer);
                compositingProperties.SetTexture(ShaderID._MaskDepth, maskDepthBuffer);
                compositingProperties.SetFloat(ShaderID._InvertMask, invertMask ? 1 : 0);
                SetViewPortSize(ctx.cmd, compositingProperties, source);
                HDUtils.DrawFullScreen(ctx.cmd, compositeMaterial, source, compositingProperties, shaderPassId: 0); // Do not forget the shaderPassId: ! or it won't work
            }
        }
    }

    // release all resources
    protected override void Cleanup()
    {
        CoreUtils.Destroy(compositeMaterial);
        CoreUtils.Destroy(whiteRenderersMaterial);
        downSampleBuffer.Release();
        blurBuffer.Release();
        maskDepthBuffer?.Release();
        maskBuffer?.Release();
        colorCopy?.Release();
    }
}