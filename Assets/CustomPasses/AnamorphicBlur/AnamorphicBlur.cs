using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

class AnamorphicBlur : CustomPass
{
    public float    xRadius = 5;
    public float    yRadius = 5;
    public int      sampleCount = 11;

    RTHandle temp;

    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        temp = RTHandles.Alloc(Vector2.one, TextureXR.slices, dimension: TextureXR.dimension, colorFormat: GraphicsFormat.R16G16B16A16_SFloat, useDynamicScale: true, name: "Temp");
    }

    protected override void Execute(CustomPassContext ctx)
    {
        var resXRadius = xRadius * ctx.cameraColorBuffer.rtHandleProperties.rtHandleScale.x;
        var resYRadius = yRadius * ctx.cameraColorBuffer.rtHandleProperties.rtHandleScale.y;

        CustomPassUtils.VerticalGaussianBlur(ctx, ctx.cameraColorBuffer, temp, sampleCount, resYRadius);
        CustomPassUtils.HorizontalGaussianBlur(ctx, temp, ctx.cameraColorBuffer, sampleCount, resXRadius);
    }

    protected override void Cleanup() => temp.Release();
}