# HDRP-Custom-Passes
A bunch of custom passes made for HDRP

## TIPS Effect:

Features:
+ Edge detect
+ Draw Mesh
+ Compositing with fullscreen pass

Source file link for this effect: [TIPS.cs](https://github.com/alelievr/HDRP-Custom-Passes/blob/master/Assets/CustomPasses/TIPS/TIPS.cs) and [TIPS.shader](https://github.com/alelievr/HDRP-Custom-Passes/blob/master/Assets/CustomPasses/TIPS/TIPS.shader)

![TIPS_Effect](https://user-images.githubusercontent.com/6877923/65622342-c9e09200-dfc5-11e9-9625-02ce78c75b11.gif)
![TIPS_Effect_Size](https://user-images.githubusercontent.com/6877923/65622971-124c7f80-dfc7-11e9-8e5c-9c9069877223.gif)
![TIPS_Effect_Color](https://user-images.githubusercontent.com/6877923/65623107-5b043880-dfc7-11e9-9bcc-426895ca09ba.gif)

## Slight Blur Effect:

Features:
+ 2 Pass gaussian blur and a downscale
+ Masking to not blur certain part of the screen using meshes

Source file link for this effect: [SlightBlur.cs](https://github.com/alelievr/HDRP-Custom-Passes/blob/master/Assets/CustomPasses/Blur/SlightBlur.cs) and [Blur.shader](https://github.com/alelievr/HDRP-Custom-Passes/blob/master/Assets/CustomPasses/Blur/Blur.shader)
![SlightBlur](https://user-images.githubusercontent.com/6877923/66118285-47179280-e5d6-11e9-9d92-1e7cc844bf03.gif)

## Outline Effect:

Source file link for this effect: [02_Selection_Objects.shader](https://github.com/alelievr/HDRP-Custom-Passes/blob/master/Assets/CustomPasses/Selection/Shaders/02_Selection_Objects.shader) and [02_Selection_Fullscreen.shader](https://github.com/alelievr/HDRP-Custom-Passes/blob/master/Assets/CustomPasses/Selection/Shaders/02_Selection_Fullscreen.shader)

Effect made without custom C#, setup in the inspector: 
![image](https://user-images.githubusercontent.com/6877923/66144393-0b49f080-e609-11e9-8251-368c8fabe548.png)

![OutlineThickness](https://user-images.githubusercontent.com/6877923/66143724-f02ab100-e607-11e9-9fbf-af639112d17a.gif)
![OutlineColor2](https://user-images.githubusercontent.com/6877923/66144282-d89ff800-e608-11e9-8f57-29604e404916.gif)

## AR Effect:

Features:
+ Early depth pass
+ Composite with video in background

![AR](https://user-images.githubusercontent.com/32760367/66135092-ac30af80-e5f9-11e9-89bf-b534ac1443bc.png)

## Glitch Effect:

Features:
+ Display a "bad reception" effect over objects of specified layer, using the following shader:
![SS_Glitch](https://user-images.githubusercontent.com/32760367/66395699-63ea0680-e9d8-11e9-88d3-d9b2e6f71837.png)

![Glitch](https://user-images.githubusercontent.com/32760367/66395665-4f0d7300-e9d8-11e9-812e-4f913405addc.gif)
