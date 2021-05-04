# HDRP-Custom-Passes
A bunch of custom passes made for HDRP. This project have been setup for Unity 2020.3 version with HDRP 10.x.

## TIPS Effect:

Features:
+ Edge detect
+ Draw Mesh
+ Compositing with fullscreen pass

Source file link for this effect: [TIPS.cs](https://github.com/alelievr/HDRP-Custom-Passes/blob/master/Assets/CustomPasses/TIPS/TIPS.cs) and [TIPS.shader](https://github.com/alelievr/HDRP-Custom-Passes/blob/master/Assets/CustomPasses/TIPS/Resources/TIPS.shader)

![TIPS_Effect](https://user-images.githubusercontent.com/6877923/65622342-c9e09200-dfc5-11e9-9625-02ce78c75b11.gif)
![TIPS_Effect_Size](https://user-images.githubusercontent.com/6877923/65622971-124c7f80-dfc7-11e9-8e5c-9c9069877223.gif)
![TIPS_Effect_Color](https://user-images.githubusercontent.com/6877923/65623107-5b043880-dfc7-11e9-9bcc-426895ca09ba.gif)

## Slight Blur Effect:

Features:
+ 2 Pass gaussian blur and a downscale
+ Masking to not blur certain part of the screen using meshes

Source file link for this effect: [SlightBlur.cs](https://github.com/alelievr/HDRP-Custom-Passes/blob/master/Assets/CustomPasses/Blur/SlightBlur.cs) and [Blur.shader](https://github.com/alelievr/HDRP-Custom-Passes/blob/master/Assets/CustomPasses/Blur/Resources/Blur.shader)
![SlightBlur](https://user-images.githubusercontent.com/6877923/66118285-47179280-e5d6-11e9-9d92-1e7cc844bf03.gif)

## Outline Effect:

Source file link for this effect: [02_Selection_Objects.shader](https://github.com/alelievr/HDRP-Custom-Passes/blob/master/Assets/CustomPasses/Selection/Shaders/02_Selection_Objects.shader) and [02_Selection_Fullscreen.shader](https://github.com/alelievr/HDRP-Custom-Passes/blob/master/Assets/CustomPasses/Selection/Shaders/02_Selection_Fullscreen.shader)

Effect made without custom C#, setup in the inspector: 
![image](https://user-images.githubusercontent.com/6877923/66144393-0b49f080-e609-11e9-8251-368c8fabe548.png)

![OutlineThickness](https://user-images.githubusercontent.com/6877923/66143724-f02ab100-e607-11e9-9fbf-af639112d17a.gif)
![OutlineColor2](https://user-images.githubusercontent.com/6877923/66144282-d89ff800-e608-11e9-8f57-29604e404916.gif)

## See Through Effect:

Source file link for this effect: [SeeThrough.cs](https://github.com/alelievr/HDRP-Custom-Passes/blob/master/Assets/CustomPasses/SeeThrough/SeeThrough.cs) and [SeeThroughStencil.shader](https://github.com/alelievr/HDRP-Custom-Passes/blob/master/Assets/CustomPasses/SeeThrough/SeeThroughStencil.shader)
![SeeThrough](https://user-images.githubusercontent.com/6877923/87780070-37e49700-c82e-11ea-9d03-d5ce2a4410c6.gif)


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

## Scrolling Formulas Effect:

Features:
+ Uses a builtin fullscreen custom pass and a custom pass fullscreen shader
+ Triplanar mapping
![ScrollingFormulas](https://user-images.githubusercontent.com/6877923/67881514-eb8ee500-fb40-11e9-9545-b2b71bd44e6e.gif)

## Liquid

Features:
+ Meta balls made by bluring normals
+ Visual Effect Graph inside a custom pass
+ Overriding depth and normals of a fullscreen transparent to emulate a surface
![Liquid](https://user-images.githubusercontent.com/6877923/68505769-57233180-0268-11ea-9137-6983e859d214.gif)

## Glass

Features:
+ Thickness aproximation using a custom pass rendering backfaces in custom depth
![image](https://user-images.githubusercontent.com/32760367/68871276-76a0db00-06fc-11ea-9f97-db4c7b98dac1.png)

## Depth Capture

Features:
+ Render objects from a different camera and output their depth in a depth buffer
![image](https://user-images.githubusercontent.com/6877923/69529388-7dd3ae80-0f70-11ea-97f9-95a60acedd8d.png)

## Render With Normal Buffer

Rendering objects in the normal buffer is essential to make objects work with screen space effects. This example show how to create a custom pass that renders an object in the depth, normal and color buffer so the SSAO can correctly be applied (you can see the exagerated SSAO effect in this screenshot)

![image](https://user-images.githubusercontent.com/6877923/94256977-e857d100-ff2a-11ea-84b9-79ff5c26c76b.png)

And this is the same image without rendering the object to the normal buffer:  
![image](https://user-images.githubusercontent.com/6877923/94257125-1b9a6000-ff2b-11ea-98d4-a592798a075b.png)
As you can see the SSAO is completely messed-up


Note that because you need to render the object in both depth-prepass and forward pass, you need two custom passes volume with different injection points:  
![image](https://user-images.githubusercontent.com/6877923/94257371-7cc23380-ff2b-11ea-8da8-895911a23103.png)

## ScreenSpace Camera UI Blur

This effect blurs the camera color buffer and renders the screenspace UI on top of it. It is intended to be used in the after post process injection point
![UI_blur](https://user-images.githubusercontent.com/6877923/99794633-c04fad00-2b2a-11eb-8cef-7f253599d5cb.gif)

Note that this custom pass also avoid z test issues when doing this kind of as the transparent objects are rendered after everything.

![image](https://user-images.githubusercontent.com/6877923/99796085-29382480-2b2d-11eb-89b8-73c1cd16af48.png)


## Render Video Without TAA

This effect allows you to render an object (for example a video player) without TAA. It uses custom post processes to achieve this, so be sure to have the "VideoPlaybackWithoutTAAPostProcess" post process in your HDRP default settings:

![image](https://user-images.githubusercontent.com/6877923/116881655-d1493200-ac23-11eb-9590-47e9a110f20e.png).

As you can see in the videos, this pass will remove all artifacts visible when an object doesn't have valid motion vector data (which is the case for most texture animation or video playback):

With TAA:  
https://user-images.githubusercontent.com/6877923/116881360-77e10300-ac23-11eb-8a19-f176d2364f11.mp4
Without TAA:  
https://user-images.githubusercontent.com/6877923/116881366-78799980-ac23-11eb-97b0-5f8aa18f9b3c.mp4

By default in this effect, the `fixDepthBufferJittering` field is disabled because it's a very costly operation (re-render all the objects in the scene into an unjittered depth buffer) but it allows to get rid of all TAA artifacts remaining after you add this effect (mainly depth jittering).

## Render Object Motion Vectors

Render the Object motion vectors (not camera motion vectors!) into a render texture
![image](https://user-images.githubusercontent.com/6877923/116994966-c05af800-acd9-11eb-8534-f582600047d2.png)
