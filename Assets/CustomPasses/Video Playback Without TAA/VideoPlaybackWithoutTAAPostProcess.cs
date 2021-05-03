using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

public class VideoPlaybackWithoutTAAPostProcess : CustomPostProcessVolumeComponent, IPostProcessComponent
{
    Material material;

    // This bit is very important because the Before Post Process injection point is just after the TAA pass, so we can composite the screen here.
    public override CustomPostProcessInjectionPoint injectionPoint => CustomPostProcessInjectionPoint.BeforePostProcess;

    public bool IsActive() => VideoPlaybackWithoutTAA.instance != null && VideoPlaybackWithoutTAA.instance.IsValid();

    public override void Setup()
    {
        material = CoreUtils.CreateEngineMaterial(Shader.Find("Hidden/CompositingWithoutTAA"));
    }

    public override void Render(CommandBuffer cmd, HDCamera camera, RTHandle source, RTHandle destination)
    {
        VideoPlaybackWithoutTAA.instance.RenderVideoObjects(cmd);
        material.SetTexture("_VideoTextureSource", VideoPlaybackWithoutTAA.instance.videoColorBuffer);
        material.SetTexture("_InputTexture", source);
        HDUtils.DrawFullScreen(cmd, material, destination, shaderPassId: 0);
    }
}