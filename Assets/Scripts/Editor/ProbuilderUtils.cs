using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.ProBuilder;

public class ProbuilderUtils : EditorWindow
{
    [MenuItem("Tools/ProBuilder/Probuilder Utils")]
    public static void ProbuilderUtils_Open()
    {
        GetWindow<ProbuilderUtils>();
    }

    string batchConvert_OrigPath="";
    string batchConvert_DestPath="";

    void OnGUI()
    {
        GUILayout.Label("Batch convert");
        batchConvert_OrigPath = EditorGUILayout.TextField("Source Path", batchConvert_OrigPath);
        batchConvert_DestPath = EditorGUILayout.TextField("Target Path", batchConvert_DestPath);

        if (GUILayout.Button("Convert"))
        {
            var prefabsGUIDs = AssetDatabase.FindAssets("t:prefab", new string[] { batchConvert_OrigPath });

            for (int i = 0; i < prefabsGUIDs.Length; i++)
            {
                var path = AssetDatabase.GUIDToAssetPath(prefabsGUIDs[i]);
                var prefab = (GameObject) AssetDatabase.LoadMainAssetAtPath(path);

                var proBuilderMesh = prefab.GetComponent<ProBuilderMesh>();
                if (proBuilderMesh == null) continue;

                var meshFilter = prefab.GetComponent<MeshFilter>();
                if (meshFilter == null ) continue;

                var meshCollider = prefab.GetComponent<MeshCollider>();

                var outPath = path.Replace(batchConvert_OrigPath.Replace("\\", "/"), batchConvert_DestPath.Replace("\\", "/"));
                outPath = outPath.Replace(".prefab", ".asset");

                var parentFolder = Path.GetDirectoryName(outPath);

                if (!AssetDatabase.IsValidFolder(parentFolder))
                {
                    var fullDirPath = Path.Combine(Application.dataPath, parentFolder.Substring(7));
                    
                    Directory.CreateDirectory(fullDirPath);
                }
                
                proBuilderMesh.ToMesh();
                proBuilderMesh.Refresh();
                
                AssetDatabase.CreateAsset( meshFilter.sharedMesh, outPath );
                var newMesh = (Mesh)AssetDatabase.LoadMainAssetAtPath(outPath);
                
                DestroyImmediate(proBuilderMesh, true);
                meshFilter.sharedMesh = newMesh;
                if (meshCollider != null) meshCollider.sharedMesh = newMesh;
            }
            
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
        }
        
        EditorGUILayout.Separator();
        
        GUILayout.Label("Scene Prefabs");

        if (GUILayout.Button("Revert mesh filters and colliders to prefabs"))
        {
            var prevSelection = Selection.objects;
            Selection.objects = null;
            
            var meshFilters = FindObjectsOfType<MeshFilter>();
            foreach (var meshFilter in meshFilters)
            {
                var so = new SerializedObject(meshFilter);
                if (PrefabUtility.IsPartOfPrefabInstance(meshFilter))
                {
                    var prop = so.FindProperty("m_Mesh");
                    PrefabUtility.RevertPropertyOverride(prop, InteractionMode.AutomatedAction);
                    so.ApplyModifiedProperties();
                }
            }
            var meshColliders = FindObjectsOfType<MeshCollider>();
            foreach (var meshcollider in meshColliders)
            {
                var so = new SerializedObject(meshcollider);
                if (PrefabUtility.IsPartOfPrefabInstance(meshcollider))
                {
                    var prop = so.FindProperty("m_Mesh");
                    PrefabUtility.RevertPropertyOverride(prop, InteractionMode.AutomatedAction);
                    so.ApplyModifiedProperties();
                }
            }

            Selection.objects = prevSelection;
        }
    }
}
