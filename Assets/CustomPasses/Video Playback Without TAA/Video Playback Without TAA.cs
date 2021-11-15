using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

#if UNITY_EDITOR
using UnityEditor.Rendering.HighDefinition;

[CustomPassDrawerAttribute(typeof(VideoPlaybackWithoutTAA))]
class VideoPlaybackWithoutTAAEditor : CustomPassDrawer
{
    protected override PassUIFlag commonPassUIFlags => PassUIFlag.Name;
}
#endif

class VideoPlaybackWithoutTAA : CustomPass
{
    public static VideoPlaybackWithoutTAA instance;

    public LayerMask videoObjectMask;
    // Option to remove the jittering caused by the jittered depth buffer around geometry intersecting the video screen.
    public bool fixDepthBufferJittering = false;
    public LayerMask fixDepthBufferJitteringMask = -1;

    internal RTHandle videoColorBuffer;
    internal RTHandle videoDepthBuffer;
    CustomPassContext context;

    public bool IsValid()
    {
        if (!enabled)
            return false;

        return videoColorBuffer?.rt != null && videoDepthBuffer?.rt != null;
    }

    protected override void AggregateCullingParameters(ref ScriptableCullingParameters cullingParameters, HDCamera hdCamera)
    {
        cullingParameters.cullingMask |= (uint)videoObjectMask.value;
        if (fixDepthBufferJittering)
            cullingParameters.cullingMask |= (uint)fixDepthBufferJitteringMask.value;
    }

    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        instance = this;
        videoColorBuffer = RTHandles.Alloc(
            Vector2.one, TextureXR.slices, dimension: TextureXR.dimension,
            colorFormat: GraphicsFormat.R16G16B16A16_SFloat, // We need alpha for this effect to detect (during compositing pass) 
            useDynamicScale: true, name: "Video Buffer"
        );

        videoDepthBuffer = RTHandles.Alloc(
            Vector2.one, TextureXR.slices, dimension: TextureXR.dimension,
            useDynamicScale: true,
            name: "non-jittered Depth Buffer", depthBufferBits: DepthBits.Depth24
        );
    }

    // This function is called from the custom post process at the before post process injection point, just after TAA
    public void RenderVideoObjects(CommandBuffer cmd)
    {
        // Fix depth buffer jittering 
        if (fixDepthBufferJittering)
        {
            using (new ProfilingScope(cmd, new ProfilingSampler("Render Depth Buffer without jittering")))
            {
                // We need to re-render everything to get the non-jittered depth buffer :/
                CoreUtils.SetRenderTarget(cmd, videoDepthBuffer);
                CoreUtils.ClearRenderTarget(cmd, ClearFlag.Depth, Color.black);
                var tags = new ShaderTagId[] { new ShaderTagId("DepthForwardOnly"), new ShaderTagId("DepthOnly") };
                var result = new UnityEngine.Rendering.RendererUtils.RendererListDesc(tags, context.cullingResults, context.hdCamera.camera)
                {
                    rendererConfiguration = PerObjectData.None,
                    renderQueueRange = RenderQueueRange.all,
                    sortingCriteria = SortingCriteria.CommonOpaque,
                    excludeObjectMotionVectors = false,
                    layerMask = fixDepthBufferJitteringMask,
                    // stateBlock = overrideRenderState,
                };
                CoreUtils.DrawRendererList(context.renderContext, context.cmd, context.renderContext.CreateRendererList(result));
            }
        }

        // TODO: add an option to render the "frame" objects in the unjittered depth-buffer to avoid flickering
        CoreUtils.SetRenderTarget(cmd, videoColorBuffer, fixDepthBufferJittering ? videoDepthBuffer : context.cameraDepthBuffer, ClearFlag.Color);
        var renderState = new RenderStateBlock(RenderStateMask.Depth)
        {
            depthState = new DepthState(false, CompareFunction.LessEqual)
        };
        CustomPassUtils.DrawRenderers(context, videoObjectMask, overrideRenderState: renderState);
    }

    // Hack because we don't have an injection point after TAA and before post processes in custom passes
    protected override void Execute(CustomPassContext ctx)
        => context = ctx;

    protected override void Cleanup()
    {
        videoColorBuffer.Release();
        videoDepthBuffer.Release();
    }
}
