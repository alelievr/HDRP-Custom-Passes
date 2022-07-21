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

    Material    compositingMaterial;
    RTHandle    blurBuffer;
    Mesh        quad;

    static class ShaderID
    {
        public static readonly int _BlitTexture = Shader.PropertyToID("_BlitTexture");
        public static readonly int _BlitScaleBias = Shader.PropertyToID("_BlitScaleBias");
        public static readonly int _BlitMipLevel = Shader.PropertyToID("_BlitMipLevel");
        public static readonly int _Radius = Shader.PropertyToID("_Radius");
        public static readonly int _Source = Shader.PropertyToID("_Source");
    }

    protected override void AggregateCullingParameters(ref ScriptableCullingParameters cullingParameters, HDCamera camera)
        => cullingParameters.cullingMask |= (uint)layerMask.value;

    public override IEnumerable<Material> RegisterMaterialForInspector()
    {
        if (transparentFullscreenShader != null)
            yield return transparentFullscreenShader;
    }

    // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
    // When empty this render pass will render to the active camera render target.
    // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
    // The render pipeline will ensure target setup and clearing happens in an performance manner.
    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        compositingMaterial = CoreUtils.CreateEngineMaterial(Shader.Find("Hidden/FullScreen/LiquidCompositing"));

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

    protected override void Execute(CustomPassContext ctx)
    {
        if (compositingMaterial == null)
        {
            Debug.LogError("Failed to load Liquid Pass Shaders");
            return;
        }

        CustomPassUtils.DrawRenderers(ctx, layerMask);

        // Blur the custom buffer:
        var resRadius = radius * ctx.cameraColorBuffer.rtHandleProperties.rtHandleScale.x;
        CustomPassUtils.GaussianBlur(ctx, ctx.customColorBuffer.Value, ctx.customColorBuffer.Value, blurBuffer, 25, resRadius);

        HandmadeFullscreenShaderGraphPass(ctx);
    }

    void HandmadeFullscreenShaderGraphPass(CustomPassContext ctx)
    {
        int pass = transparentFullscreenShader.FindPass("Forward");
        if (pass == -1)
            pass = transparentFullscreenShader.FindPass("ForwardOnly");

        // Move the mesh to the far plane of the camera
        float forwardDistance = ctx.hdCamera.camera.nearClipPlane + 0.0001f;
        var transform = ctx.hdCamera.camera.transform;
        var trs = Matrix4x4.TRS(
            transform.position + transform.forward * forwardDistance,
            transform.rotation,
            Vector3.one);

        CoreUtils.SetRenderTarget(ctx.cmd, ctx.cameraColorBuffer, ctx.cameraDepthBuffer);
        ctx.cmd.DrawMesh(quad, trs, transparentFullscreenShader, 0, pass);
    }

    protected override void Cleanup()
    {
        CoreUtils.Destroy(compositingMaterial);
        CoreUtils.Destroy(quad);
        blurBuffer.Release();
    }
}