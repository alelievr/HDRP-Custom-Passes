#pragma once

// First stage
void generateMoments(float depth, float transmittance, out float b_0, out float4 b) {
    float absorbance = -log(transmittance);

	b_0 = absorbance;
	float depth_pow2 = depth * depth;
	float depth_pow4 = depth_pow2 * depth_pow2;
	b = float4(depth, depth_pow2, depth_pow2 * depth, depth_pow4) * absorbance;
}

// Basic fused multiplication and addition. No precision benefit here, only to keep closer to the original implementation
float fma(float a, float b, float c) {
    return a*b+c;
}

// Heart of the method. Used in the second stage
float computeTransmittanceAtDepthFrom4PowerMoments(float b_0, float2 b_even, float2 b_odd, float depth, float bias, float overestimation, float4 bias_vector) {
    float4 b = float4(b_odd.x, b_even.x, b_odd.y, b_even.y);
    
    // Bias input data to avoid artifacts
    b = lerp(b, bias_vector, bias);
    float3 z;
    z[0] = depth;

    // Compute a Cholesky factorization of the Hankel matrix B storing only non-
    // trivial entries or related products
    float L21D11               = fma(-b[0],b[1],b[2]);
    float D11                  = fma(-b[0],b[0], b[1]);
    float InvD11               = 1.0f/D11;
    float L21                  = L21D11*InvD11;
    float SquaredDepthVariance = fma(-b[1],b[1], b[3]);
    float D22                  = fma(-L21D11,L21,SquaredDepthVariance);

    // Obtain a scaled inverse image of bz=(1,z[0],z[0]*z[0])^T
    float3 c = float3(1.0f,z[0],z[0]*z[0]);
    
    // Forward substitution to solve L*c1=bz
    c[1] -= b.x;
    c[2] -= b.y+L21*c[1];
    
    // Scaling to solve D*c2=c1
    c[1] *= InvD11;
    c[2] /= D22;
    
    // Backward substitution to solve L^T*c3=c2
    c[1] -= L21*c[2];
    c[0] -= dot(c.yz,b.xy);
    
    // Solve the quadratic equation c[0]+c[1]*z+c[2]*z^2 to obtain solutions 
    // z[1] and z[2]
    float InvC2= 1.0f/c[2];
    float p    = c[1]*InvC2;
    float q    = c[0]*InvC2;
    float D    = (p*p*0.25f)-q;
    float r    = sqrt(D);
    z[1] = -p*0.5f-r;
    z[2] = -p*0.5f+r;

    // Compute the absorbance by summing the appropriate weights
    float3 polynomial;
    float3 weight_factor = float3(overestimation, (z[1] < z[0])?1.0f:0.0f, (z[2] < z[0])?1.0f:0.0f);

    float f0   = weight_factor[0];
    float f1   = weight_factor[1];
    float f2   = weight_factor[2];
    float f01  = (f1-f0)/(z[1]-z[0]);
    float f12  = (f2-f1)/(z[2]-z[1]);
    float f012 = (f12-f01)/(z[2]-z[0]);

    polynomial[0] = f012;
    polynomial[1] = polynomial[0];
    polynomial[0] = f01-polynomial[0]*z[1];
    polynomial[2] = polynomial[1];
    polynomial[1] = polynomial[0]-polynomial[1]*z[0];
    polynomial[0] = f0-polynomial[0]*z[0];

    float absorbance = polynomial[0] + dot(b.xy, polynomial.yz);

    // Turn the normalized absorbance into transmittance
    return clamp(exp(-b_0 * absorbance), 0.0, 1.0);
}
    
// Second stage
void resolveMoments(float zeroth_moment, float4 moments, out float transmittance_at_depth, out float total_transmittance, float depth) {
    total_transmittance = 1.0;
    transmittance_at_depth = 1.0;

    float b_0 = zeroth_moment;
    if(b_0 - 0.00100050033f < 0.0) return;// discard; // In the original code you would discard here

    total_transmittance = exp(-b_0);

    float4 b_1234 = moments;
    float2 b_even = b_1234.yw;
    float2 b_odd = b_1234.xz;

    b_even /= b_0;
    b_odd /= b_0;

    const float4 bias_vector = float4(0.0, 0.375, 0.0, 0.375);
    
    float moment_bias = 1e-4;
    float overestimation = 0.25;

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