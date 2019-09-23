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
    }

    SerializedProperty		m_Mesh;
    SerializedProperty		m_Size;
    SerializedProperty		m_RotationSpeed;

    protected override void Initialize(SerializedProperty customPass)
    {
        m_Mesh = customPass.FindPropertyRelative("mesh");
        m_Size = customPass.FindPropertyRelative("size");
        m_RotationSpeed = customPass.FindPropertyRelative("rotationSpeed");
    }

    protected override void DoPassGUI(SerializedProperty customPass, Rect rect)
    {
        m_Mesh.objectReferenceValue = EditorGUI.ObjectField(rect, Styles.mesh, m_Mesh.objectReferenceValue, typeof(Mesh), false);
        rect.y += Styles.defaultLineSpace;

        m_Size.floatValue = EditorGUI.Slider(rect, Styles.size, m_Size.floatValue, 0.1f, 100f);
        rect.y += Styles.defaultLineSpace;
        m_RotationSpeed.floatValue = EditorGUI.Slider(rect, Styles.rotationSpeed, m_RotationSpeed.floatValue, 0f, 30f);
    }

    protected override float GetPassHeight(SerializedProperty customPass) => Styles.defaultLineSpace * 3;
}

#endif

class TIPS : CustomPass
{
    public Mesh     mesh = null;
    public float    size = 5;
    public float    rotationSpeed = 5;

    public Material material;

    Material    fullscreenMaterial;
    RTHandle    tipsBuffer; // additional render target for compositing the custom and camera color buffers

    int         compositingPass;
    int         copyPass;

    // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
    // When empty this render pass will render to the active camera render target.
    // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
    // The render pipeline will ensure target setup and clearing happens in an performance manner.
    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        material = Resources.Load<Material>("Shader Graphs_TIPS_Effect");
        fullscreenMaterial = CoreUtils.CreateEngineMaterial("FullScreen/TIPS");
        tipsBuffer = RTHandles.Alloc(Vector2.one, TextureXR.slices, dimension: TextureXR.dimension, colorFormat: GraphicsFormat.R16G16B16A16_SFloat, useDynamicScale: true, name: "TIPS Buffer");

        compositingPass = fullscreenMaterial.FindPass("Compositing");
        copyPass = fullscreenMaterial.FindPass("Copy");
    }

    protected override void Execute(ScriptableRenderContext renderContext, CommandBuffer cmd, HDCamera camera, CullingResults cullingResult)
    {
        if (mesh == null || material == null || fullscreenMaterial == null)
            return ;

        Transform cameraTransform = camera.camera.transform;
        Matrix4x4 trs = Matrix4x4.TRS(cameraTransform.position, Quaternion.Euler(0f, Time.realtimeSinceStartup * rotationSpeed, Time.realtimeSinceStartup * rotationSpeed * 0.5f), Vector3.one * size);
        cmd.DrawMesh(mesh, trs, material, 0, material.FindPass("ForwardOnly"));

        fullscreenMaterial.SetTexture("_TIPSBuffer", tipsBuffer);
        CoreUtils.SetRenderTarget(cmd, tipsBuffer, ClearFlag.All);
        CoreUtils.DrawFullScreen(cmd, fullscreenMaterial, shaderPassId: compositingPass);

        SetCameraRenderTarget(cmd);
        CoreUtils.DrawFullScreen(cmd, fullscreenMaterial, shaderPassId: copyPass);
    }

    protected override void Cleanup()
    {
        CoreUtils.Destroy(fullscreenMaterial);
        tipsBuffer.Release();
    }
}