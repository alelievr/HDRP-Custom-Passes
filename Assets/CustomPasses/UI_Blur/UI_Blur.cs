using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

#if UNITY_EDITOR

using UnityEditor.Rendering.HighDefinition;
using UnityEditor;

[CustomPassDrawerAttribute(typeof(ScreenSpaceCameraUIBlur))]
class ScreenSpaceCameraUIBlurEditor : CustomPassDrawer
{
    protected override PassUIFlag commonPassUIFlags => PassUIFlag.Name;
}

#endif

class ScreenSpaceCameraUIBlur : CustomPass
{
    public float        blurRadius = 10;
    public LayerMask    uiLayer = 1 << 5;

    RTHandle            downSampleBuffer;

    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        if (injectionPoint != CustomPassInjectionPoint.AfterPostProcess)
            Debug.LogWarning("Custom Pass UI Blur isn't using the after post process injection point. Your post processes will be applied to the UI");

        // Allocate the buffers used for the blur in half resolution to save some memory
        downSampleBuffer = RTHandles.Alloc(
            Vector2.one * 0.5f, TextureXR.slices, dimension: TextureXR.dimension,
            colorFormat: GraphicsFormat.B10G11R11_UFloatPack32, // We don't need alpha in the blur
            useDynamicScale: true, name: "DownSampleBuffer"
        );
    }

    protected override void AggregateCullingParameters(ref ScriptableCullingParameters cullingParameters, HDCamera hdCamera)
    {
        cullingParameters.cullingMask |= (uint)uiLayer.value;
    }

    protected override void Execute(CustomPassContext ctx)
    {
        // This pass doesn't work with scene views
        if (ctx.hdCamera.camera.cameraType == CameraType.SceneView)
            return;

        CustomPassUtils.GaussianBlur(ctx, ctx.cameraColorBuffer, ctx.cameraColorBuffer, downSampleBuffer, radius: blurRadius);

        CoreUtils.SetRenderTarget(ctx.cmd, ctx.cameraColorBuffer, ctx.customDepthBuffer.Value, ClearFlag.DepthStencil, Color.clear);
        CustomPassUtils.DrawRenderers(ctx, uiLayer, RenderQueueType.Transparent, sorting: SortingCriteria.CommonTransparent);
    }

    protected override void Cleanup()
    {
        downSampleBuffer.Release();
    }
}