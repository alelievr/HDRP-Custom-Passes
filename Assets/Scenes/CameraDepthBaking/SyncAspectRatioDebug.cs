using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

[ExecuteAlways]
public class SyncAspectRatioDebug : MonoBehaviour
{
    public RawImage ui;
    public RenderTexture debugtexture;

    public float debugSize = 0.3f;

    RectTransform rt;

    void Start() => rt = GetComponent<RectTransform>();

    void Update()
    {
        ui.texture = debugtexture;
        rt.sizeDelta = new Vector2(debugtexture.width, debugtexture.height) * debugSize;
    }
}
