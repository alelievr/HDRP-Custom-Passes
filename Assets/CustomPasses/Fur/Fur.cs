using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;
using System.Runtime.InteropServices;

class Fur : CustomPass
{
    public LayerMask    furMask = 0;
    public Mesh         furMesh = null;
    public Material     furMaterial = null;
    ShaderTagId[]       shaderTags;

    Material            scatterFurPointsMaterial;
    ComputeBuffer       furData;
    ComputeBuffer       drawFurBuffer;
    uint[]              drawArgs;

    [GenerateHLSL]
    struct FurData
    {
        public Vector3  position;

        public FurData(Vector3 p) => position = p;
    }

    // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
    // When empty this render pass will render to the active camera render target.
    // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
    // The render pipeline will ensure target setup and clearing happens in an performance manner.
    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        scatterFurPointsMaterial = CoreUtils.CreateEngineMaterial(Shader.Find("Hidden/Fur/ScatterPointsOnRenderers"));

        // We are forced to initialize everything in the constructor instead of in the class because of SerializeReference ...
        shaderTags = new ShaderTagId[4]
        {
            new ShaderTagId("Forward"),
            new ShaderTagId("ForwardOnly"),
            new ShaderTagId("SRPDefaultUnlit"),
            new ShaderTagId("FirstPass"),
        };
        drawArgs = new uint[]{0, 0, 0, 0, 0};
        furData = new ComputeBuffer(65536, Marshal.SizeOf(typeof(FurData)), ComputeBufferType.Append);
        furData.name = "FurData";
        drawFurBuffer = new ComputeBuffer(1, sizeof(int) * drawArgs.Length, ComputeBufferType.IndirectArguments);
        drawFurBuffer.name = "DrawFurBuffer";
        drawFurBuffer.SetData(drawArgs);
        Debug.Log("Alloc Setup buffers !");

    }

    protected override void Execute(CustomPassContext ctx)
    {
        if (scatterFurPointsMaterial == null)
            return;

        furData.SetCounterValue(0);

        DrawObjectToFurify(ctx.renderContext, ctx.cmd, ctx.hdCamera, ctx.cullingResults);
        // Executed every frame for all the camera inside the pass volume
    }

    void DrawObjectToFurify(ScriptableRenderContext renderContext, CommandBuffer cmd, HDCamera hdCamera, CullingResults cullingResult)
    {
        var result = new RendererListDesc(shaderTags, cullingResult, hdCamera.camera)
        {
            rendererConfiguration = PerObjectData.None,
            renderQueueRange = RenderQueueRange.all,
            sortingCriteria = SortingCriteria.BackToFront,
            excludeObjectMotionVectors = false,
            overrideMaterial = scatterFurPointsMaterial,
            overrideMaterialPassIndex = 0,
            layerMask = furMask,
        };

        scatterFurPointsMaterial.SetBuffer("furData", furData);
        // CoreUtils.SetRenderTarget(cmd, furMask, maskDepthBuffer, ClearFlag.All);
        CoreUtils.DrawRendererList(renderContext, cmd, RendererList.Create(result));

        if (furMesh != null && furMaterial != null)
        {
            //Update draw arguments:
            drawArgs[0] = furMesh.GetIndexCount(0);
            drawArgs[1] = 100; // this is filled by the geometry shader
            drawArgs[2] = furMesh.GetIndexStart(0);
            drawArgs[3] = furMesh.GetBaseVertex(0);

            drawFurBuffer.SetData(drawArgs);
            furMaterial.SetBuffer("furData", furData);
            cmd.DrawMeshInstancedIndirect(furMesh, 0, furMaterial, 0, drawFurBuffer);
        }
    }

    protected override void Cleanup()
    {
        Debug.Log("Remove fur buffer !");
        furData.Release();
        drawFurBuffer.Release();
        CoreUtils.Destroy(scatterFurPointsMaterial);
    }
}