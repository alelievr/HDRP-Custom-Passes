using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;

#if UNITY_EDITOR
using UnityEditor;
using UnityEditor.Rendering.HighDefinition;

[CustomPassDrawer(typeof(CopyPass))]
public class CopyPassDrawer : CustomPassDrawer
{
    protected override PassUIFlag commonPassUIFlags => PassUIFlag.Name;
}

#endif

public class CopyPass : CustomPass
{
    public enum BufferType
    {
        Color,
        Normal,
        Roughness,
        Depth,
        MotionVectors,
    }

    public RenderTexture outputRenderTexture;

    [SerializeField, HideInInspector]
    Shader customCopyShader;
    Material customCopyMaterial;

    public BufferType bufferType;

    protected override bool executeInSceneView => false;

    int normalPass;
    int roughnessPass;
    int depthPass;

    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        if (customCopyShader == null)
            customCopyShader = Shader.Find("Hidden/FullScreen/CustomCopy");
        customCopyMaterial = CoreUtils.CreateEngineMaterial(customCopyShader);

        normalPass = customCopyMaterial.FindPass("Normal");
        roughnessPass = customCopyMaterial.FindPass("Roughness");
        depthPass = customCopyMaterial.FindPass("Depth");
    }

    protected override void Execute(CustomPassContext ctx)
    {
        if (outputRenderTexture == null || customCopyMaterial == null)
            return;

        SyncRenderTextureAspect(outputRenderTexture, ctx.hdCamera.camera);

        var scale = RTHandles.rtHandleProperties.rtHandleScale;
        customCopyMaterial.SetVector("_Scale", scale);

        switch (bufferType)
        {
            default:
            case BufferType.Color:
                ctx.cmd.Blit(ctx.cameraColorBuffer, outputRenderTexture, new Vector2(scale.x, scale.y), Vector2.zero, 0, 0);
                break;
            case BufferType.Normal:
                ctx.cmd.Blit(ctx.cameraNormalBuffer, outputRenderTexture, customCopyMaterial, normalPass);
                break;
            case BufferType.Roughness:
                ctx.cmd.Blit(ctx.cameraNormalBuffer, outputRenderTexture, customCopyMaterial, roughnessPass);
                break;
            case BufferType.Depth:
                ctx.cmd.Blit(ctx.cameraNormalBuffer, outputRenderTexture, customCopyMaterial, depthPass);
                break;
            case BufferType.MotionVectors:
                ctx.cmd.Blit(ctx.cameraMotionVectorsBuffer, outputRenderTexture, new Vector2(scale.x, scale.y), Vector2.zero, 0, 0);
                break;
        }
    }

    void SyncRenderTextureAspect(RenderTexture rt, Camera camera)
    {
        float aspect = rt.width / (float)rt.height;

        if (!Mathf.Approximately(aspect, camera.aspect))
        {
            rt.Release();
            rt.width = camera.pixelWidth;
            rt.height = camera.pixelHeight;
            rt.Create();
        }
    }

    protected override void Cleanup()
    {
        CoreUtils.Destroy(customCopyMaterial);
    }
}