using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

#if UNITY_EDITOR

using UnityEditor.Rendering.HighDefinition;

[CustomPassDrawer(typeof(FPSForeground))]
class FPSForegroundEditor : CustomPassDrawer
{
    protected override PassUIFlag commonPassUIFlags => PassUIFlag.Name;
}

#endif

class FPSForeground : CustomPass
{
    public float        fov = 45;
    public LayerMask    foregroundMask;

    Camera              foregroundCamera;

    const string        kCameraTag = "_FPSForegroundCamera";

    Material            depthClearMaterial;

    RTHandle            trueDepthBuffer;

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
            cam.AddComponent<Camera>();
        }

        depthClearMaterial = new Material(Shader.Find("Hidden/Renderers/ForegroundDepthClear"));

        var trueDethBuffer = new RenderTargetIdentifier(BuiltinRenderTextureType.Depth);

        trueDepthBuffer = RTHandles.Alloc(trueDethBuffer);

        foregroundCamera = cam.GetComponent<Camera>();
    }

    protected override void Execute(CustomPassContext ctx)
    {
        // Disable it for scene view because it's horrible
        if (ctx.hdCamera.camera.cameraType == CameraType.SceneView)
            return;

        var currentCam = ctx.hdCamera.camera;

        // Copy settings of our current camera
        foregroundCamera.transform.SetPositionAndRotation(currentCam.transform.position, currentCam.transform.rotation);
        foregroundCamera.CopyFrom(ctx.hdCamera.camera);
        // Make sure the camera is disabled, we don't want it to render anything.
        foregroundCamera.enabled = false;
        foregroundCamera.fieldOfView = fov;
        foregroundCamera.cullingMask = foregroundMask;

        var depthTestOverride = new RenderStateBlock(RenderStateMask.Depth)
        {
            depthState = new DepthState(true, CompareFunction.LessEqual),
        };

        // TODO: Nuke the depth in the after depth and normal injection point
        // Override depth to 0 (avoid artifacts with screen-space effects)
        CoreUtils.SetKeyword(ctx.cmd, "WRITE_NORMAL_BUFFER", true);
        ctx.cmd.SetRenderTarget(ctx.cameraNormalBuffer, trueDepthBuffer, 0, CubemapFace.Unknown, 0); // TODO: make it work in VR
        RenderFromCameraDepthPass(ctx, foregroundCamera, null, null, ClearFlag.None, foregroundMask, overrideMaterial: depthClearMaterial, overrideMaterialIndex: 0);
        CoreUtils.SetKeyword(ctx.cmd, "WRITE_NORMAL_BUFFER", false);

        // Render the object color or normal + depth depending on the injection point
        if (injectionPoint == CustomPassInjectionPoint.AfterOpaqueDepthAndNormal)
        {
            CoreUtils.SetKeyword(ctx.cmd, "WRITE_NORMAL_BUFFER", true);
            RenderFromCameraDepthPass(ctx, foregroundCamera, ctx.cameraNormalBuffer, ctx.cameraDepthBuffer, ClearFlag.None, foregroundMask, overrideRenderState: depthTestOverride);
            CoreUtils.SetKeyword(ctx.cmd, "WRITE_NORMAL_BUFFER", false);
        }
        else
            CustomPassUtils.RenderFromCamera(ctx, foregroundCamera, ctx.cameraColorBuffer, ctx.cameraDepthBuffer, ClearFlag.None, foregroundMask, overrideRenderState: depthTestOverride);
    }


    public void RenderFromCameraDepthPass(in CustomPassContext ctx, Camera view, RTHandle targetColor, RTHandle targetDepth, ClearFlag clearFlag, LayerMask layerMask, CustomPass.RenderQueueType renderQueueFilter = CustomPass.RenderQueueType.All, Material overrideMaterial = null, int overrideMaterialIndex = 0, RenderStateBlock overrideRenderState = default(RenderStateBlock))
    {
        ShaderTagId[] depthTags = { HDShaderPassNames.s_DepthForwardOnlyName, HDShaderPassNames.s_DepthOnlyName };
        if (targetColor != null && targetDepth != null)
            CoreUtils.SetRenderTarget(ctx.cmd, targetColor, targetDepth, clearFlag);
        else if (targetColor != null)
            CoreUtils.SetRenderTarget(ctx.cmd, targetColor, clearFlag);
        else if (targetDepth != null)
            CoreUtils.SetRenderTarget(ctx.cmd, targetDepth, clearFlag);

        using (new CustomPassUtils.DisableSinglePassRendering(ctx))
        {
            using (new CustomPassUtils.OverrideCameraRendering(ctx, view))
            {
                // using (new ProfilingScope(ctx.cmd, renderFromCameraSampler))
                    CustomPassUtils.DrawRenderers(ctx, depthTags, layerMask, renderQueueFilter, overrideMaterial, overrideMaterialIndex, overrideRenderState);
            }
        }
    }

    protected override void Cleanup()
    {
        trueDepthBuffer.Release();
        CoreUtils.Destroy(depthClearMaterial);
        // CoreUtils.Destroy(foregroundCamera);
    }
}