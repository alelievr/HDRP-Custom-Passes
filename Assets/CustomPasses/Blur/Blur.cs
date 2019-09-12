using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

class Blur : CustomPass
{
    [Range(0, 8)]
    public float    radius = 4;

    Material        fullscreenMaterial;
    RTHandle        blurBuffer;

    // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
    // When empty this render pass will render to the active camera render target.
    // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
    // The render pipeline will ensure target setup and clearing happens in an performance manner.
    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        fullscreenMaterial = CoreUtils.CreateEngineMaterial(Shader.Find("FullScreen/Blur"));
        blurBuffer = RTHandles.Alloc(Vector2.one, TextureXR.slices, dimension: TextureXR.dimension, colorFormat: GraphicsFormat.R16G16B16A16_SFloat, useDynamicScale: true, name: "BlurBuffer");
    }

    protected override void Execute(ScriptableRenderContext renderContext, CommandBuffer cmd, HDCamera camera, CullingResults cullingResult)
    {
        if (fullscreenMaterial != null)
        {
            // copy the mip x from the camera color buffer into the blur buffer
            CoreUtils.SetRenderTarget(cmd, blurBuffer, ClearFlag.All);
            fullscreenMaterial.SetFloat("_Radius", radius / 4.0f); // The blur is 4 pixel wide in the shader
            CoreUtils.DrawFullScreen(cmd, fullscreenMaterial, shaderPassId: 0); // Do not forget the shaderPassId: ! or it won't work

            // Copy back the result in the camera color buffer
            SetCameraRenderTarget(cmd);
            fullscreenMaterial.SetTexture("_BlurBuffer", blurBuffer);
            CoreUtils.DrawFullScreen(cmd, fullscreenMaterial, shaderPassId: 1);
        }
    }

    protected override void Cleanup()
    {
        CoreUtils.Destroy(fullscreenMaterial);
        blurBuffer.Release();
    }
}