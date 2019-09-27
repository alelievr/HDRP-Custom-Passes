using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

[ExecuteAlways]
public class LinkedScenes : MonoBehaviour
{
#if UNITY_EDITOR
    [SerializeField]
#endif

    SceneAsset[] linkedScenes;
    
#if UNITY_EDITOR
    void OnEnable()
    {
        if (linkedScenes != null && linkedScenes.Length > 0)
        {
            for (int i = 0; i < linkedScenes.Length; ++i)
            {
                EditorSceneManager.OpenScene(AssetDatabase.GetAssetPath(linkedScenes[i]), OpenSceneMode.Additive);
            }

            EditorSceneManager.SetActiveScene(EditorSceneManager.GetSceneAt(0));
        }
    }

#endif
    
}
