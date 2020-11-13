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

        if (sceneNames != null && sceneNames.Length > 0)
        {
            int countLoaded = SceneManager.sceneCount;
            Scene[] loadedScenes = new Scene[countLoaded];
            for (int i = 0; i < countLoaded; i++)
                loadedScenes[i] = SceneManager.GetSceneAt(i);
            for (int i = 0; i < sceneNames.Length; ++i)
            {
                // discard scene if it's already loaded
                if (loadedScenes.Any(s => s.name == sceneNames[i]))
                    continue;

#if UNITY_EDITOR
                if (Application.isPlaying)
                    SceneManager.LoadScene(sceneNames[i], LoadSceneMode.Additive);
                else
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
