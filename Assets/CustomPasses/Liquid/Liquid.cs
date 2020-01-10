using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Profiling;
using System.Collections.Generic;
using System.Collections;

#if UNITY_EDITOR
using UnityEditor;
using UnityEditor.Rendering.HighDefinition;

[CustomPassDrawer(typeof(Liquid))]
class LiquidDrawer : CustomPassDrawer
{
    protected override PassUIFlag commonPassUIFlags => PassUIFlag.Name;
}
#endif

class Liquid : CustomPass
{
    [Range(0, 64)]
    public float        radius = 4;
    public LayerMask    layerMask = 0;
    public Material     transparentFullscreenShader = null;

    Material    blurMaterial;
    Material    compositingMaterial;
    RTHandle    downSampleBuffer;
    RTHandle    blurBuffer;
    Mesh        quad;

    ShaderTagId[] shaderTags;

    static class ShaderID
    {
        public static readonly int _BlitTexture = Shader.PropertyToID("_BlitTexture");
        public static readonly int _BlitScaleBias = Shader.PropertyToID("_BlitScaleBias");
        public static readonly int _BlitMipLevel = Shader.PropertyToID("_BlitMipLevel");
        public static readonly int _Radius = Shader.PropertyToID("_Radius");
        public static readonly int _Source = Shader.PropertyToID("_Source");
        public static readonly int _ViewPortSize = Shader.PropertyToID("_ViewPortSize");
    }

    protected override void AggregateCullingParameters(ref ScriptableCullingParameters cullingParameters, HDCamera camera)
        => cullingParameters.cullingMask |= (uint)layerMask.value;


    // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
    // When empty this render pass will render to the active camera render target.
    // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
    // The render pipeline will ensure target setup and clearing happens in an performance manner.
    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        blurMaterial = CoreUtils.CreateEngineMaterial(Shader.Find("Hidden/FullScreen/BlurPasses"));
        compositingMaterial = CoreUtils.CreateEngineMaterial(Shader.Find("Hidden/FullScreen/LiquidCompositing"));

        shaderTags = new ShaderTagId[4]
        {
            new ShaderTagId("Forward"),
            new ShaderTagId("ForwardOnly"),
            new ShaderTagId("SRPDefaultUnlit"),
            new ShaderTagId("FirstPass"),
        };

        // Allocate the buffers used for the blur in half resolution to save some memory
        downSampleBuffer = RTHandles.Alloc(
            Vector2.one * 0.5f, TextureXR.slices, dimension: TextureXR.dimension,
            colorFormat: GraphicsFormat.R16G16B16A16_SNorm,
            useDynamicScale: true, name: "DownSampleBuffer"
        );

        blurBuffer = RTHandles.Alloc(
            Vector2.one * 0.5f, TextureXR.slices, dimension: TextureXR.dimension,
            colorFormat: GraphicsFormat.R16G16B16A16_SNorm,
            useDynamicScale: true, name: "BlurBuffer"
        );

        targetColorBuffer = TargetBuffer.Custom;
        targetDepthBuffer = TargetBuffer.Custom;
        clearFlags = ClearFlag.All;

        quad = new Mesh();
        quad.SetVertices(new List< Vector3 >{
            new Vector3(-1, -1, 0),
            new Vector3( 1, -1, 0),
            new Vector3(-1,  1, 0),
            new Vector3( 1,  1, 0),
        });
        quad.SetTriangles(new List<int>{
            0, 3, 1, 0, 2, 3
        }, 0);
        quad.RecalculateBounds();

        quad.UploadMeshData(false);
    }

    protected override void Execute(ScriptableRenderContext renderContext, CommandBuffer cmd, HDCamera hdCamera, CullingResults cullingResult)
    {
        if (compositingMaterial == null || blurMaterial == null)
        {
            Debug.LogError("Failed to load Liquid Pass Shaders");
            return;
        }

        var result = new RendererListDesc(shaderTags, cullingResult, hdCamera.camera)
        {
            rendererConfiguration = PerObjectData.None,
            renderQueueRange = RenderQueueRange.all,
            sortingCriteria = SortingCriteria.BackToFront,
            excludeObjectMotionVectors = false,
            layerMask = layerMask.value,
        };

        // Render objects into the custom buffer:
        HDUtils.DrawRendererList(renderContext, cmd, RendererList.Create(result));

        // Blur the custom buffer:
        BlurCustomBuffer(cmd, hdCamera);

        // Composite the result into the camera color buffer
        SetCameraRenderTarget(cmd);
        int pass = transparentFullscreenShader.FindPass("Forward");
        if (pass == -1)
            pass = transparentFullscreenShader.FindPass("ForwardOnly");

        // Move the mesh to the far plane of the camera
        float ForwardDistance = hdCamera.camera.nearClipPlane + 0.0001f;
        cmd.DrawMesh(quad, Matrix4x4.TRS(hdCamera.camera.transform.position + hdCamera.camera.transform.forward * ForwardDistance, hdCamera.camera.transform.rotation, Vector3.one), transparentFullscreenShader, 0, pass);
    }

    // We need the viewport size in our shader because we're using half resolution render targets (and so the _ScreenSize
    // variable in the shader does not match the viewport).
    void SetBlurParams(CommandBuffer cmd, MaterialPropertyBlock block, RTHandle target, Camera cam)
    {
        Vector2Int scaledViewportSize = target.GetScaledSize(target.rtHandleProperties.currentViewportSize);
        block.SetVector(ShaderID._ViewPortSize, new Vector4(scaledViewportSize.x, scaledViewportSize.y, 1.0f / scaledViewportSize.x, 1.0f / scaledViewportSize.y));
    }
    
    void BlurCustomBuffer(CommandBuffer cmd, HDCamera hdCam)
    {
        GetCustomBuffers(out var customColorBuffer, out var _);

        // Downsample
        using (new ProfilingSample(cmd, "Downsample", CustomSampler.Create("Downsample")))
        {
            // This Blit will automatically downsample the color because our target buffer have been allocated in half resolution
            HDUtils.BlitCameraTexture(cmd, customColorBuffer, downSampleBuffer, 0, true);
        }

        // Horizontal Blur
        using (new ProfilingSample(cmd, "H Blur", CustomSampler.Create("H Blur")))
        {
            var hBlurProperties = new MaterialPropertyBlock();
            hBlurProperties.SetFloat(ShaderID._Radius, radius / 100.0f);
            hBlurProperties.SetTexture(ShaderID._Source, downSampleBuffer); // The blur is 4 pixel wide in the shader
            SetBlurParams(cmd, hBlurProperties, blurBuffer, hdCam.camera);
            HDUtils.DrawFullScreen(cmd, blurMaterial, blurBuffer, hBlurProperties, shaderPassId: 0); // Do not forget the shaderPassId: ! or it won't work
        }

        // Copy back the result in the color buffer while doing a vertical blur
        using (new ProfilingSample(cmd, "V Blur + Copy back", CustomSampler.Create("V Blur + Copy back")))
        {
            var vBlurProperties = new MaterialPropertyBlock();
            // When we use a mask, we do the vertical blur into the downsampling buffer instead of the camera buffer
            // We need that because we're going to write to the color buffer and read from this blured buffer which we can't do
            // if they are in the same buffer
            vBlurProperties.SetFloat(ShaderID._Radius, radius / 100.0f);
            vBlurProperties.SetTexture(ShaderID._Source, blurBuffer);
            SetBlurParams(cmd, vBlurProperties, customColorBuffer, hdCam.camera);
            HDUtils.DrawFullScreen(cmd, blurMaterial, customColorBuffer, vBlurProperties, shaderPassId: 1); // Do not forget the shaderPassId: ! or it won't work
        }
    }

    protected override void Cleanup()
    {
        CoreUtils.Destroy(blurMaterial);
        CoreUtils.Destroy(compositingMaterial);
        CoreUtils.Destroy(quad);
        downSampleBuffer.Release();
        blurBuffer.Release();
    }
}