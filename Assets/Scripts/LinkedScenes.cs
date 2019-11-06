using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
#if UNITY_EDITOR
using UnityEditor;
using UnityEditor.SceneManagement;
#endif
using UnityEngine.SceneManagement;
using UnityEngine;

[ExecuteAlways]
public class LinkedScenes : MonoBehaviour
{
#if UNITY_EDITOR
    [SerializeField]
    SceneAsset[] linkedScenes = null;
#endif

    [SerializeField]
    string[]    sceneNames;
    
    void Start()
    {
#if UNITY_EDITOR
        // Update scene names in editor only
        sceneNames = linkedScenes.Select(l => l.name).ToArray();
#endif

        if (Application.isPlaying) return;
        
        if (sceneNames != null && sceneNames.Length > 0)
        {
            for (int i = 0; i < sceneNames.Length; ++i)
            {
#if UNITY_EDITOR
                EditorSceneManager.OpenScene(AssetDatabase.GetAssetPath(linkedScenes[i]), OpenSceneMode.Additive);
#else
                SceneManager.LoadScene(sceneNames[i], LoadSceneMode.Additive);
#endif
            }

#if UNITY_EDITOR
            EditorSceneManager.SetActiveScene(EditorSceneManager.GetSceneAt(0));
#endif
        }
    }
}
