using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

#if UNITY_EDITOR

using UnityEditor.Rendering.HighDefinition;
using UnityEditor;

[CustomPassDrawerAttribute(typeof(TIPS))]
class TIPSEditor : CustomPassDrawer
{
    private class Styles
    {
        public static float defaultLineSpace = EditorGUIUtility.singleLineHeight + EditorGUIUtility.standardVerticalSpacing;

        public static GUIContent mesh = new GUIContent("Mesh", "Mesh used for the scanner effect.");
        public static GUIContent size = new GUIContent("Size", "Size of the effect.");
        public static GUIContent rotationSpeed = new GUIContent("Speed", "Speed of rotation.");
        public static GUIContent edgeThreshold = new GUIContent("Edge Threshold", "Edge detect effect threshold.");
        public static GUIContent edgeRadius = new GUIContent("Edge Radius", "Radius of the edge detect effect.");
        public static GUIContent glowColor = new GUIContent("Color", "Color of the effect");
    }

    SerializedProperty		mesh;
    SerializedProperty		size;
    SerializedProperty		rotationSpeed;
    SerializedProperty		edgeDetectThreshold;
    SerializedProperty		edgeRadius;
    SerializedProperty		glowColor;

    protected override void Initialize(SerializedProperty customPass)
    {
        mesh = customPass.FindPropertyRelative("mesh");
        size = customPass.FindPropertyRelative("size");
        rotationSpeed = customPass.FindPropertyRelative("rotationSpeed");
        edgeDetectThreshold = customPass.FindPropertyRelative("edgeDetectThreshold");
        edgeRadius = customPass.FindPropertyRelative("edgeRadius");
        glowColor = customPass.FindPropertyRelative("glowColor");
    }

    // We only need the name to be displayed, the rest is controlled by the TIPS effect
    protected override PassUIFlag commonPassUIFlags => PassUIFlag.Name;

    protected override void DoPassGUI(SerializedProperty customPass, Rect rect)
    {
        mesh.objectReferenceValue = EditorGUI.ObjectField(rect, Styles.mesh, mesh.objectReferenceValue, typeof(Mesh), false);
        rect.y += Styles.defaultLineSpace;

        size.floatValue = EditorGUI.Slider(rect, Styles.size, size.floatValue, 0.2f, TIPS.kMaxDistance);
        rect.y += Styles.defaultLineSpace;
        rotationSpeed.floatValue = EditorGUI.Slider(rect, Styles.rotationSpeed, rotationSpeed.floatValue, 0f, 30f);
        rect.y += Styles.defaultLineSpace;
        edgeDetectThreshold.floatValue = EditorGUI.Slider(rect, Styles.edgeThreshold, edgeDetectThreshold.floatValue, 0.1f, 5f);
        rect.y += Styles.defaultLineSpace;
        edgeRadius.intValue = EditorGUI.IntSlider(rect, Styles.edgeRadius, edgeRadius.intValue, 1, 6);
        rect.y += Styles.defaultLineSpace;
        glowColor.colorValue = EditorGUI.ColorField(rect, Styles.glowColor, glowColor.colorValue, true, false, true);
    }

    protected override float GetPassHeight(SerializedProperty customPass) => Styles.defaultLineSpace * 6;
}

#endif

class TIPS : CustomPass
{
    public Mesh     mesh = null;
    public float    size = 5;
    public float    rotationSpeed = 5;
    public float    edgeDetectThreshold = 1;
    public int      edgeRadius = 2;
    public Color    glowColor = Color.white;

    public const float  kMaxDistance = 1000;

    public Material tipsMeshMaterial;

    Material    fullscreenMaterial;
    RTHandle    tipsBuffer; // additional render target for compositing the custom and camera color buffers

    int         compositingPass;
    int         blurPass;

    // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
    // When empty this render pass will render to the active camera render target.
    // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
    // The render pipeline will ensure target setup and clearing happens in an performance manner.
    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        tipsMeshMaterial = Resources.Load<Material>("Shader Graphs_TIPS_Effect");
        fullscreenMaterial = CoreUtils.CreateEngineMaterial("FullScreen/TIPS");
        tipsBuffer = RTHandles.Alloc(Vector2.one, TextureXR.slices, dimension: TextureXR.dimension, colorFormat: GraphicsFormat.R16G16B16A16_SFloat, useDynamicScale: true, name: "TIPS Buffer");

        compositingPass = fullscreenMaterial.FindPass("Compositing");
        blurPass = fullscreenMaterial.FindPass("Blur");
        targetColorBuffer = TargetBuffer.Custom;
        targetDepthBuffer = TargetBuffer.Custom;
        clearFlags = ClearFlag.All;
    }

    protected override void Execute(CustomPassContext ctx)
    {
        if (fullscreenMaterial == null)
            return ;

        if (mesh != null && tipsMeshMaterial != null)
        {
            Transform cameraTransform = ctx.hdCamera.camera.transform;
            Matrix4x4 trs = Matrix4x4.TRS(cameraTransform.position, Quaternion.Euler(0f, Time.realtimeSinceStartup * rotationSpeed, Time.realtimeSinceStartup * rotationSpeed * 0.5f), Vector3.one * size);
            tipsMeshMaterial.SetFloat("_Intensity", (0.2f / size) * kMaxDistance);
            ctx.cmd.DrawMesh(mesh, trs, tipsMeshMaterial, 0, tipsMeshMaterial.FindPass("ForwardOnly"));
        }

        ctx.propertyBlock.SetTexture("_TIPSBuffer", tipsBuffer);
        ctx.propertyBlock.SetFloat("_EdgeDetectThreshold", edgeDetectThreshold);
        ctx.propertyBlock.SetColor("_GlowColor", glowColor);
        ctx.propertyBlock.SetFloat("_EdgeRadius", (float)edgeRadius);
        ctx.propertyBlock.SetFloat("_BypassMeshDepth", (mesh != null) ? 0 : size);
        // CustomPassUtils.FullScreenPass(ctx, fullscreenMaterial, compositingPass, tipsBuffer, clearFlag: ClearFlag.Color);
        CoreUtils.SetRenderTarget(ctx.cmd, tipsBuffer, ClearFlag.Color);
        CoreUtils.DrawFullScreen(ctx.cmd, fullscreenMaterial, shaderPassId: compositingPass, properties: ctx.propertyBlock);

        // CustomPassUtils.FullScreenPass(ctx, fullscreenMaterial, blurPass, ctx.cameraColorBuffer);
        CoreUtils.DrawFullScreen(ctx.cmd, fullscreenMaterial, ctx.cameraColorBuffer, shaderPassId: blurPass, properties: ctx.propertyBlock);
    }

    protected override void Cleanup()
    {
        CoreUtils.Destroy(fullscreenMaterial);
        tipsBuffer.Release();
    }
}