/*! \file
	This header provides the functionality to create the vectors of moments and 
	to blend surfaces together with an appropriately reconstructed 
	transmittance. It is needed for both additive passes of moment-based OIT.
*/
#ifndef MOMENT_OIT_HLSLI
#define MOMENT_OIT_HLSLI

float overestimation;
float moment_bias;

// CUSTOM CONFIG:
#define NUM_MOMENTS 4
#define SINGLE_PRECISION 1

#include "MomentMath.hlsli"

RasterizerOrderedTexture2DArray<float> b0 : register(u0);

// /*! This function handles the actual computation of the new vector of power 
// 	moments.*/
// void generatePowerMoments(inout float b_0,
// 	inout float2 b_even, inout float2 b_odd,
// 	float depth, float transmittance)
// {
// 	float absorbance = -log(transmittance);

// 	float depth_pow2 = depth * depth;
// 	float depth_pow4 = depth_pow2 * depth_pow2;

// #if SINGLE_PRECISION
// 	b_0 += absorbance;
// 	b_even += float2(depth_pow2, depth_pow4) * absorbance;
// 	b_odd += float2(depth, depth_pow2 * depth) * absorbance;
// #else // Quantized
// 	offsetMoments(b_even, b_odd, -1.0);
// 	b_even *= b_0;
// 	b_odd *= b_0;

// 	//  New Moments
// 	float2 b_even_new = float2(depth_pow2, depth_pow4);
// 	float2 b_odd_new = float2(depth, depth_pow2 * depth);
// 	float2 b_even_new_q, b_odd_new_q;
// 	quantizeMoments(b_even_new_q, b_odd_new_q, b_even_new, b_odd_new);

// 	// Combine Moments
// 	b_0 += absorbance;
// 	b_even += b_even_new_q * absorbance;
// 	b_odd += b_odd_new_q * absorbance;

// 	// Go back to interval [0, 1]
// 	b_even /= b_0;
// 	b_odd /= b_0;
// 	offsetMoments(b_even, b_odd, 1.0);
// #endif
// }

// /*! This function reads the stored moments from the rasterizer ordered view, 
// 	calls the appropriate moment-generating function and writes the new moments 
// 	back to the rasterizer ordered view.*/
// void generateMoments(float depth, float transmittance, float2 sv_pos)
// {
// 	uint3 idx0 = uint3(sv_pos, 0);
// 	uint3 idx1 = idx0;
// 	idx1[2] = 1;

// 	// Return early if the surface is fully transparent
// 	clip(0.9999999f - transmittance);

// 	float b_0 = b0[idx0];
// 	float4 b_raw = b[idx0];

// 	float2 b_even = b_raw.yw;
// 	float2 b_odd = b_raw.xz;

// 	generatePowerMoments(b_0, b_even, b_odd, depth, transmittance);

// 	b[idx0] = float4(b_odd.x, b_even.x, b_odd.y, b_even.y);
// 	b0[idx0] = b_0;

// }

/*! This functions relies on fixed function additive blending to compute the 
	vector of moments.moment vector. The shader that calls this function must 
	provide the required render targets.*/
void generateMoments(float depth, float transmittance, out float b_0, out float4 b)
{
	float absorbance = -log(transmittance);

	b_0 = absorbance;
	float depth_pow2 = depth * depth;
	float depth_pow4 = depth_pow2 * depth_pow2;
	b = float4(depth, depth_pow2, depth_pow2 * depth, depth_pow4) * absorbance;
}

/*! This function is to be called from the shader that composites the 
	transparent fragments. It reads the moments and calls the appropriate 
	function to reconstruct the transmittance at the specified depth.*/
void resolveMoments(out float transmittance_at_depth, out float total_transmittance, float depth, float zeroth_moment, float4 moments)
{
	transmittance_at_depth = 1;
	total_transmittance = 1;
	
	float b_0 = zeroth_moment;
	clip(b_0 - 0.00100050033f);
	total_transmittance = exp(-b_0);

	float4 b_1234 = moments;
#if SINGLE_PRECISION
	float2 b_even = b_1234.yw;
	float2 b_odd = b_1234.xz;

	b_even /= b_0;
	b_odd /= b_0;

	const float4 bias_vector = float4(0, 0.375, 0, 0.375);
#else
	float2 b_even_q = b_1234.yw;
	float2 b_odd_q = b_1234.xz;

	// Dequantize the moments
	float2 b_even;
	float2 b_odd;
	offsetAndDequantizeMoments(b_even, b_odd, b_even_q, b_odd_q);
	const float4 bias_vector = float4(0, 0.628, 0, 0.628);
#endif
	transmittance_at_depth = computeTransmittanceAtDepthFrom4PowerMoments(b_0, b_even, b_odd, depth, moment_bias, overestimation, bias_vector);
}

// Final Compositing (section 3.4)
float3 compositeOIT(float3 opaqueColor, float4 resolvedTransparentColor, float totalTransmittance)
{
    return opaqueColor * totalTransmittance + resolvedTransparentColor.rgb * (1.0 - totalTransmittance);
}

float3 CompositeOIT2(float zerothMoment, float3 opaqueColor, float3 resolvedTransparentColor)
{
    return exp(-zerothMoment) * opaqueColor + resolvedTransparentColor;
}

#endif // MOMENT_OIT_HLSLI