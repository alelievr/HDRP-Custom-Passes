using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

class ScrollingFormulas : CustomPass
{
    public Texture2D    scrollingFormula = null;

    Material            scrollingFullscreen;

    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        // Setup code here
    }

    protected override void Execute(ScriptableRenderContext renderContext, CommandBuffer cmd, HDCamera camera, CullingResults cullingResult)
    {
        // Executed every frame for all the camera inside the pass volume
    }

    protected override void Cleanup()
    {
        // Cleanup code
    }
}