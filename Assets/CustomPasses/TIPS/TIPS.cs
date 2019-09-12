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
    }

    SerializedProperty		m_Mesh;
    SerializedProperty		m_Size;

    protected override void Initialize(SerializedProperty customPass)
    {
        m_Mesh = customPass.FindPropertyRelative("mesh");
        m_Size = customPass.FindPropertyRelative("size");
    }

    protected override void DoPassGUI(SerializedProperty customPass, Rect rect)
    {
        m_Mesh.objectReferenceValue = EditorGUI.ObjectField(rect, Styles.mesh, m_Mesh.objectReferenceValue, typeof(Mesh), false);
        rect.y += Styles.defaultLineSpace;

        m_Size.floatValue = EditorGUI.Slider(rect, Styles.size, m_Size.floatValue, 0.1f, 100f);
    }

    protected override float GetPassHeight(SerializedProperty customPass) => Styles.defaultLineSpace * 2;
}

#endif

class TIPS : CustomPass
{
    public Mesh     mesh = null;
    public float    size = 5;

    public Material material;

    // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
    // When empty this render pass will render to the active camera render target.
    // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
    // The render pipeline will ensure target setup and clearing happens in an performance manner.
    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        material = Resources.Load<Material>("Shader Graphs_TIPS_Effect");
    }

    protected override void Execute(ScriptableRenderContext renderContext, CommandBuffer cmd, HDCamera camera, CullingResults cullingResult)
    {
        if (mesh == null || material == null)
            return ;

        Matrix4x4 trs = Matrix4x4.TRS(camera.camera.transform.position, Quaternion.identity, Vector3.one * size);
        cmd.DrawMesh(mesh, trs, material, 0, material.FindPass("ForwardOnly"));
    }

    protected override void Cleanup()
    {
    }
}