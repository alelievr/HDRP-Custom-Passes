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

        CustomPassUtils.RenderFromCamera(ctx, foregroundCamera, ctx.cameraColorBuffer, ctx.cameraDepthBuffer, ClearFlag.None, foregroundMask, overrideRenderState: depthTestOverride);
    }

    protected override void Cleanup()
    {
        // CoreUtils.Destroy(foregroundCamera);
    }
}