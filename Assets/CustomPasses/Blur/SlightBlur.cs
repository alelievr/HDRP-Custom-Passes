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

    Material        blurMaterial;
    Material        whiteRenderersMaterial;
    RTHandle        downSampleBuffer;
    RTHandle        blurBuffer;
    RTHandle        maskBuffer;
    RTHandle        maskDepthBuffer;
    RTHandle        colorCopy;
    ShaderTagId[]   shaderTags;

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
        public static readonly int _UVScale = Shader.PropertyToID("_UVScale");
        public static readonly int _InvertMask = Shader.PropertyToID("_InvertMask");
    }

    // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
    // When empty this render pass will render to the active camera render target.
    // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
    // The render pipeline will ensure target setup and clearing happens in an performance manner.
    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        blurMaterial = CoreUtils.CreateEngineMaterial(Shader.Find("Hidden/FullScreen/Blur"));
        whiteRenderersMaterial = CoreUtils.CreateEngineMaterial(Shader.Find("Hidden/Renderers/WhiteRenderers"));

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
                    colorFormat: (GraphicsFormat)colorBufferFormat, // We don't need alpha in the blur
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
                    colorFormat: GraphicsFormat.R16_UInt, useDynamicScale: true, isShadowMap: true,
                    name: "Blur Depth Mask", depthBufferBits: DepthBits.Depth16
                );
            }
        }
    }

    protected override void Execute(ScriptableRenderContext renderContext, CommandBuffer cmd, HDCamera hdCamera, CullingResults cullingResult)
    {
        AllocateMaskBuffersIfNeeded();

        if (blurMaterial != null && radius > 0)
        {
            if (useMask)
            {
                DrawMaskObjects(renderContext, cmd, hdCamera, cullingResult);
            }

            GenerateGaussianMips(cmd, hdCamera);
        }
    }

    void DrawMaskObjects(ScriptableRenderContext renderContext, CommandBuffer cmd, HDCamera hdCamera, CullingResults cullingResult)
    {
        // Render the objects in the layer blur mask into a mask buffer with their materials so we keep the alpha-clip and transparency if there is any.
        var result = new RendererListDesc(shaderTags, cullingResult, hdCamera.camera)
        {
            rendererConfiguration = PerObjectData.None,
            renderQueueRange = RenderQueueRange.all,
            sortingCriteria = SortingCriteria.BackToFront,
            excludeObjectMotionVectors = false,
            layerMask = maskLayer,
        };

        CoreUtils.SetRenderTarget(cmd, maskBuffer, maskDepthBuffer, ClearFlag.All);
        HDUtils.DrawRendererList(renderContext, cmd, RendererList.Create(result));
    }

    void GenerateGaussianMips(CommandBuffer cmd, HDCamera hdCam)
    {
        RTHandle source;
        Vector2Int size = new Vector2Int(hdCam.actualWidth, hdCam.actualHeight);

        if (targetColorBuffer == TargetBuffer.Camera)
            GetCameraBuffers(out source, out _);
        else
            GetCustomBuffers(out source, out _);

        int dstMipWidth  = Mathf.Max(1, size.x  >> 1);
        int dstMipHeight = Mathf.Max(1, size.y >> 1);

        // Scale for downsample
        float scaleX = ((float)size.x / source.rt.width);
        float scaleY = ((float)size.y / source.rt.height);

        if (useMask)
        {
            // Save the non blurred color into a copy:
            cmd.CopyTexture(source, colorCopy);
        }

        // Downsample.
        using (new ProfilingSample(cmd, "Downsample", CustomSampler.Create("Downsample")))
        {
            var downsampleProperties = new MaterialPropertyBlock();
            downsampleProperties.SetTexture(ShaderID._BlitTexture, source);
            downsampleProperties.SetVector(ShaderID._BlitScaleBias, new Vector4(scaleX, scaleY, 0f, 0f));
            downsampleProperties.SetFloat(ShaderID._BlitMipLevel, 0);
            CoreUtils.SetRenderTarget(cmd, downSampleBuffer, ClearFlag.None);
            cmd.SetViewport(new Rect(0, 0, dstMipWidth, dstMipHeight));
            cmd.DrawProcedural(Matrix4x4.identity, HDUtils.GetBlitMaterial(source.rt.dimension), 1, MeshTopology.Triangles, 3, 1, downsampleProperties);
        }

        // Horizontal Blur
        using (new ProfilingSample(cmd, "H Blur", CustomSampler.Create("H Blur")))
        {
            var hBlurProperties = new MaterialPropertyBlock();
            CoreUtils.SetRenderTarget(cmd, blurBuffer, ClearFlag.None);
            hBlurProperties.SetFloat(ShaderID._Radius, radius / 4.0f); // The blur is 4 pixel wide in the shader
            hBlurProperties.SetTexture(ShaderID._Source, downSampleBuffer); // The blur is 4 pixel wide in the shader
            hBlurProperties.SetFloat(ShaderID._UVScale, 2);
            cmd.SetViewport(new Rect(0, 0, dstMipWidth, dstMipHeight));
            CoreUtils.DrawFullScreen(cmd, blurMaterial, shaderPassId: 0, properties: hBlurProperties); // Do not forget the shaderPassId: ! or it won't work
        }

        // Copy back the result in the color buffer while doing a vertical blur
        using (new ProfilingSample(cmd, "V Blur + Copy back", CustomSampler.Create("V Blur + Copy back")))
        {
            var vBlurProperties = new MaterialPropertyBlock();
            // When we use a mask, we do the vertical blur into the downsampling buffer instead of the camera buffer
            // We need that because we're going to write to the color buffer and read from this blured buffer which we can't do
            // if they are in the same buffer
            CoreUtils.SetRenderTarget(cmd, (useMask) ? downSampleBuffer : source, ClearFlag.None);
            vBlurProperties.SetFloat(ShaderID._Radius, radius / 4.0f); // The blur is 4 pixel wide in the shader
            vBlurProperties.SetTexture(ShaderID._Source, blurBuffer);
            vBlurProperties.SetFloat(ShaderID._UVScale, (useMask) ? 2 : 1);
            CoreUtils.DrawFullScreen(cmd, blurMaterial, shaderPassId: 1, properties: vBlurProperties);
        }

        if (useMask)
        {
            using (new ProfilingSample(cmd, "Compose Mask Blur", CustomSampler.Create("Compose Mask Blur")))
            {
                var compositingProperties = new MaterialPropertyBlock();

                CoreUtils.SetRenderTarget(cmd, source, ClearFlag.None);
                compositingProperties.SetFloat(ShaderID._Radius, radius / 4.0f); // The blur is 4 pixel wide in the shader
                compositingProperties.SetTexture(ShaderID._Source, downSampleBuffer);
                compositingProperties.SetTexture(ShaderID._ColorBufferCopy, colorCopy);
                compositingProperties.SetTexture(ShaderID._Mask, maskBuffer);
                compositingProperties.SetTexture(ShaderID._MaskDepth, maskDepthBuffer);
                compositingProperties.SetFloat(ShaderID._InvertMask, invertMask ? 1 : 0);
                CoreUtils.DrawFullScreen(cmd, blurMaterial, shaderPassId: 2, properties: compositingProperties);
            }
        }
    }

    protected override void Cleanup()
    {
        CoreUtils.Destroy(blurMaterial);
        CoreUtils.Destroy(whiteRenderersMaterial);
        downSampleBuffer.Release();
        blurBuffer.Release();
        maskBuffer?.Release();
        colorCopy?.Release();
    }
}