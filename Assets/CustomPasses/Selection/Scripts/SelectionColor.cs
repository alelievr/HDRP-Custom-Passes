using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Renderer))]
public class SelectionColor : MonoBehaviour
{
    public Color selectionColor = new Color(1f, 0.5f, 0f, 1f);

    // Start is called before the first frame update
    void Start()
    {
        SetColor();
    }

    void OnValidate()
    {
        SetColor();
    }

    void SetColor()
    {
        var rndr = GetComponent<Renderer>();

        var propertyBlock = new MaterialPropertyBlock();
        rndr.GetPropertyBlock(propertyBlock);

        propertyBlock.SetColor("_SelectionColor", selectionColor);

        rndr.SetPropertyBlock(propertyBlock);
    }
}
