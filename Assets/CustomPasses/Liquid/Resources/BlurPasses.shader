Shader "Hidden/FullScreen/BlurPasses"
{
	HLSLINCLUDE

	#pragma vertex Vert

	#pragma target 4.5
	#pragma only_renderers d3d11 ps4 xboxone vulkan metal switch
	#pragma enable_d3d11_debug_symbols

	#include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/CustomPass/CustomPassCommon.hlsl"

	TEXTURE2D_X(_Source);
	TEXTURE2D_X(_ColorBufferCopy);
	TEXTURE2D_X_HALF(_Mask);
	TEXTURE2D_X_HALF(_MaskDepth);
	float _Radius;
	float _InvertMask;
	float4 _ViewPortSize; // We need the viewport size because we have a non fullscreen render target (blur buffers are downsampled in half res)

	#define SAMPLE_COUNT 32
	static float gaussianWeights[SAMPLE_COUNT] = {0.03740084,
		0.03723684,
		0.03674915,
		0.03595048,
		0.03486142,
		0.03350953,
		0.03192822,
		0.03015531,
		0.02823164,
		0.02619939,
		0.02410068,
		0.02197609,
		0.01986344,
		0.01779678,
		0.01580561,
		0.01391439,
		0.01214227,
		0.01050313,
		0.009005766,
		0.007654299,
		0.006448714,
		0.005385472,
		0.004458177,
		0.003658254,
		0.002975593,
		0.002399142,
		0.001917438,
		0.001519042,
		0.001192892,
		0.0009285718,
		0.0007164943,
		0.0005480157,
	};

	float2 GetSampleUVs(Varyings varyings)
	{
		return varyings.positionCS.xy * _ViewPortSize.zw;
		// TODO: simplify this
		float depth = LoadCameraDepth(varyings.positionCS.xy);
		//float linearDepth = Linear01Depth(depth,_ZBufferParams);
		PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ViewPortSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);
		return posInput.positionNDC.xy * _RTHandleScale;
	}

	float2 ClampUV(float2 uv)
	{
		return clamp(uv, _ScreenSize.zw, _RTHandleScale - _ScreenSize.zw * 2);
	}


	float4 HorizontalBlur(Varyings varyings) : SV_Target
	{
		UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);
		float2 texcoord = GetSampleUVs(varyings);

		float4 color = SAMPLE_TEXTURE2D_X_LOD(_Source, s_trilinear_clamp_sampler, ClampUV(texcoord), 0) * gaussianWeights[0];

		float linearDepth = LinearEyeDepth(SampleCustomDepth(texcoord), _ZBufferParams);

		float radius = (_Radius / linearDepth) / SAMPLE_COUNT;
		for (int j = 1; j < SAMPLE_COUNT; j++)
		{
			float2 uvOffset = float2(1, 0) * j * radius;

			color += SAMPLE_TEXTURE2D_X_LOD(_Source, s_trilinear_clamp_sampler, ClampUV(texcoord + uvOffset), 0) * gaussianWeights[j];
			color += SAMPLE_TEXTURE2D_X_LOD(_Source, s_trilinear_clamp_sampler, ClampUV(texcoord - uvOffset), 0) * gaussianWeights[j];
		}

		return color;
	}

	float4 VerticalBlur(Varyings varyings) : SV_Target
	{
		UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);
		float2 texcoord = GetSampleUVs(varyings);

		float4 color = SAMPLE_TEXTURE2D_X_LOD(_Source, s_trilinear_clamp_sampler, ClampUV(texcoord), 0) * gaussianWeights[0];

		float linearDepth = LinearEyeDepth(SampleCustomDepth(texcoord), _ZBufferParams);

		float radius = (_Radius / linearDepth) / SAMPLE_COUNT;
		for (int j = 1; j < SAMPLE_COUNT; j++)
		{
			float2 uvOffset = float2(0, 1) * j * radius;

			color += SAMPLE_TEXTURE2D_X_LOD(_Source, s_trilinear_clamp_sampler, ClampUV(texcoord + uvOffset), 0) * gaussianWeights[j];
			color += SAMPLE_TEXTURE2D_X_LOD(_Source, s_trilinear_clamp_sampler, ClampUV(texcoord - uvOffset), 0) * gaussianWeights[j];
		}

		return color;
	}

	ENDHLSL

	SubShader
	{
		Pass
		{
			// Horizontal Blur from the camera color LOD
			Name "Horizontal Blur"

			ZWrite Off
			ZTest Always
			Blend Off
			Cull Off

			HLSLPROGRAM
				#pragma fragment HorizontalBlur
			ENDHLSL
		}

		Pass
		{
			// Vertical Blur from the blur buffer back to camera color
			Name "Vertical Blur"

			ZWrite Off
			ZTest Always
			Blend Off
			Cull Off

			HLSLPROGRAM
				#pragma fragment VerticalBlur
			ENDHLSL
		}

	}
	Fallback Off
}