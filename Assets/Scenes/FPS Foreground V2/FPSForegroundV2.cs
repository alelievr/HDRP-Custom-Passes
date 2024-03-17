using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

#if UNITY_EDITOR

using UnityEditor.Rendering.HighDefinition;

[CustomPassDrawer(typeof(FPSForegroundV2))]
class FPSForegroundV2Editor : CustomPassDrawer
{
    protected override PassUIFlag commonPassUIFlags => PassUIFlag.Name;
}

#endif

class FPSForegroundV2 : CustomPass
{
    public float        fov = 45;
    public LayerMask    foregroundMask;
    public bool         supportTransparency;

    Camera              foregroundCamera;

    const string        kCameraTag = "_FPSForegroundCameraV2";

    Material            foregroundCompositingMaterial;
    [SerializeField] // Make sure shader is embedded in build
    Shader              foregroundCompositingShader;
    int                 compositingPassIndex;

    protected override bool executeInSceneView => false;

    protected override void AggregateCullingParameters(ref ScriptableCullingParameters cullingParameters, HDCamera hdCamera)
        => cullingParameters.cullingMask |= (uint)foregroundMask.value;

    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        // Hidden foreground camera:
        var cam = GameObject.Find(kCameraTag);
        if (cam == null)
        {
            cam = new GameObject(kCameraTag);
            // cam = new GameObject(kCameraTag) { hideFlags = HideFlags.HideAndDontSave };
            foregroundCamera = cam.AddComponent<Camera>();
        }
        else
        {
            foregroundCamera = cam.GetComponent<Camera>();
        }

        foregroundCompositingShader = Shader.Find("Hidden/FullScreen/ForegroundCompositing");
        foregroundCompositingMaterial = CoreUtils.CreateEngineMaterial(foregroundCompositingShader);
        compositingPassIndex = foregroundCompositingMaterial.FindPass("Compositing");
    }

    protected override void Execute(CustomPassContext ctx)
    {
        var currentCam = ctx.hdCamera.camera;

        // Copy settings of our current camera
        foregroundCamera.transform.SetPositionAndRotation(currentCam.transform.position, currentCam.transform.rotation);
        foregroundCamera.CopyFrom(ctx.hdCamera.camera);
        // Make sure the camera is disabled, we don't want it to render anything.
        foregroundCamera.enabled = false;
        foregroundCamera.fieldOfView = fov;
        foregroundCamera.cullingMask = foregroundMask;

        // Make sure that objects renders when the depth buffer is empty.
        var overrideDepthState = new RenderStateBlock(RenderStateMask.Depth)
        {
            depthState = new DepthState(true, CompareFunction.LessEqual)
        };

        // Bind empty AO and contact shadow textures so that they don't affect the foreground layer
        // Note that Shader.Get is not in sync with the command buffer so we're getting buffer from the previous
        // camera, but because buffers are reused between camera it works.
        var currentAO = Shader.GetGlobalTexture("_AmbientOcclusionTexture");
        var currentContactShadow = Shader.GetGlobalTexture("_ContactShadowTexture");
        ctx.cmd.SetGlobalTexture("_AmbientOcclusionTexture", TextureXR.GetBlackTexture());
        ctx.cmd.SetGlobalTexture("_ContactShadowTexture", TextureXR.GetBlackTexture());

        // TODO: check if it's possible to support subsurface scattering in the foreground layer
        // We need to copy the stencil and split lighting from custom buffers for this.

        // Render all the foreground objects into another texture using the custom camera FOV
        // It ensures that no objects from the scene will affect the foreground layer while still maintaining depth test inside the layer
        CoreUtils.SetRenderTarget(ctx.cmd, ctx.customColorBuffer.Value, ctx.customDepthBuffer.Value, ClearFlag.All); 
        CustomPassUtils.RenderFromCamera(ctx, foregroundCamera, foregroundMask, overrideRenderState: overrideDepthState);

        // Restore global texture state for the rest of the rendering (probably not needed but safer) 
        ctx.cmd.SetGlobalTexture("_AmbientOcclusionTexture", currentAO);
        ctx.cmd.SetGlobalTexture("_ContactShadowTexture", currentContactShadow);

        // Composite back the foreground layer with the camera buffers, we need to overwrite both depth and color
        // to make sure that screen space effects applied after this pass behave as normally as possible.
        CoreUtils.SetRenderTarget(ctx.cmd, new RenderTargetIdentifier[]{ ctx.cameraColorBuffer, ctx.cameraMotionVectorsBuffer }, ctx.cameraDepthBuffer);
        if (supportTransparency)
        {
            foregroundCompositingMaterial.SetFloat("_SrcColorBlendMode", (int)BlendMode.SrcAlpha);
            foregroundCompositingMaterial.SetFloat("_DstColorBlendMode", (int)BlendMode.OneMinusSrcAlpha);
        }
        else
        {
            // Can't disable blending block when using C# properties so we just do an overwriting blend
            foregroundCompositingMaterial.SetFloat("_SrcColorBlendMode", (int)BlendMode.One);
            foregroundCompositingMaterial.SetFloat("_DstColorBlendMode", (int)BlendMode.Zero);
        }
        CoreUtils.DrawFullScreen(ctx.cmd, foregroundCompositingMaterial, shaderPassId: compositingPassIndex);
    }

    protected override void Cleanup()
    {
        var cam = GameObject.Find(kCameraTag);
        Object.DestroyImmediate(cam);
        CoreUtils.Destroy(foregroundCompositingMaterial);
    }
}