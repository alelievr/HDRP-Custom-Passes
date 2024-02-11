/*! \file
	This header provides utility functions to reconstruct the transmittance 
	from a given vector of power moments (4, 6 or 8 power moments) at a 
	specified depth. As prerequisite, utility functions for computing the real 
	roots of polynomials up to degree four are defined.
*/
#ifndef MOMENT_MATH_HLSLI
#define MOMENT_MATH_HLSLI

#include "TrigonometricMomentMath.hlsli"

/*! Given coefficients of a quadratic polynomial A*x^2+B*x+C, this function	
	outputs its two real roots.*/
float2 solveQuadratic(float3 coeffs)
{
	coeffs[1] *= 0.5;

	float x1, x2, tmp;

	tmp = (coeffs[1] * coeffs[1] - coeffs[0] * coeffs[2]);
	if (coeffs[1] >= 0) {
		tmp = sqrt(tmp);
		x1 = (-coeffs[2]) / (coeffs[1] + tmp);
		x2 = (-coeffs[1] - tmp) / coeffs[0];
	} else {
		tmp = sqrt(tmp);
		x1 = (-coeffs[1] + tmp) / coeffs[0];
		x2 = coeffs[2] / (-coeffs[1] + tmp);
	}
	return float2(x1, x2);
}

/*! Code taken from the blog "Moments in Graphics" by Christoph Peters.
	http://momentsingraphics.de/?p=105
	This function computes the three real roots of a cubic polynomial 
	Coefficient[0]+Coefficient[1]*x+Coefficient[2]*x^2+Coefficient[3]*x^3.*/
float3 SolveCubic(float4 Coefficient) {
	// Normalize the polynomial
	Coefficient.xyz /= Coefficient.w;
	// Divide middle coefficients by three
	Coefficient.yz /= 3.0f;
	// Compute the Hessian and the discrimant
	float3 Delta = float3(
		mad(-Coefficient.z, Coefficient.z, Coefficient.y),
		mad(-Coefficient.y, Coefficient.z, Coefficient.x),
		dot(float2(Coefficient.z, -Coefficient.y), Coefficient.xy)
		);
	float Discriminant = dot(float2(4.0f*Delta.x, -Delta.y), Delta.zy);
	// Compute coefficients of the depressed cubic 
	// (third is zero, fourth is one)
	float2 Depressed = float2(
		mad(-2.0f*Coefficient.z, Delta.x, Delta.y),
		Delta.x
		);
	// Take the cubic root of a normalized complex number
	float Theta = atan2(sqrt(Discriminant), -Depressed.x) / 3.0f;
	float2 CubicRoot;
	sincos(Theta, CubicRoot.y, CubicRoot.x);
	// Compute the three roots, scale appropriately and 
	// revert the depression transform
	float3 Root = float3(
		CubicRoot.x,
		dot(float2(-0.5f, -0.5f*sqrt(3.0f)), CubicRoot),
		dot(float2(-0.5f, 0.5f*sqrt(3.0f)), CubicRoot)
		);
	Root = mad(2.0f*sqrt(-Depressed.y), Root, -Coefficient.z);
	return Root;
}

/*! Given coefficients of a cubic polynomial 
	coeffs[0]+coeffs[1]*x+coeffs[2]*x^2+coeffs[3]*x^3 with three real roots, 
	this function returns the root of least magnitude.*/
float solveCubicBlinnSmallest(float4 coeffs)
{
	coeffs.xyz /= coeffs.w;
	coeffs.yz /= 3.0;

	float3 delta = float3(mad(-coeffs.z, coeffs.z, coeffs.y), mad(-coeffs.z, coeffs.y, coeffs.x), coeffs.z * coeffs.x - coeffs.y * coeffs.y);
	float discriminant = 4.0 * delta.x * delta.z - delta.y * delta.y;

	float2 depressed = float2(delta.z, -coeffs.x * delta.y + 2.0 * coeffs.y * delta.z);
	float theta = abs(atan2(coeffs.x * sqrt(discriminant), -depressed.y)) / 3.0;
	float2 sin_cos;
	sincos(theta, sin_cos.x, sin_cos.y);
	float tmp = 2.0 * sqrt(-depressed.x);
	float2 x = float2(tmp * sin_cos.y, tmp * (-0.5 * sin_cos.y - 0.5 * sqrt(3.0) * sin_cos.x));
	float2 s = (x.x + x.y < 2.0 * coeffs.y) ? float2(-coeffs.x, x.x + coeffs.y) : float2(-coeffs.x, x.y + coeffs.y);

	return  s.x / s.y;
}

/*! Given coefficients of a quartic polynomial 
	coeffs[0]+coeffs[1]*x+coeffs[2]*x^2+coeffs[3]*x^3+coeffs[4]*x^4 with four 
	real roots, this function returns all roots.*/
float4 solveQuarticNeumark(float coeffs[5])
{
	// Normalization
	float B = coeffs[3] / coeffs[4];
	float C = coeffs[2] / coeffs[4];
	float D = coeffs[1] / coeffs[4];
	float E = coeffs[0] / coeffs[4];

	// Compute coefficients of the cubic resolvent
	float P = -2.0*C;
	float Q = C*C + B*D - 4.0*E;
	float R = D*D + B*B*E -B*C*D;

	// Obtain the smallest cubic root
	float y = solveCubicBlinnSmallest(float4(R, Q, P, 1.0));

	float BB = B*B;
	float fy = 4.0 * y;
	float BB_fy = BB - fy;

	float Z = C - y;
	float ZZ = Z*Z;
	float fE = 4.0 * E;
	float ZZ_fE = ZZ - fE;

	float G, g, H, h;
	// Compute the coefficients of the quadratics adaptively using the two 
	// proposed factorizations by Neumark. Choose the appropriate 
	// factorizations using the heuristic proposed by Herbison-Evans.
	if(y < 0 || (ZZ + fE) * BB_fy > ZZ_fE * (BB + fy)) {
		float tmp = sqrt(BB_fy);
		G = (B + tmp) * 0.5;
		g = (B - tmp) * 0.5;

		tmp = (B*Z - 2.0*D) / (2.0*tmp);
		H = mad(Z, 0.5, tmp);
		h = mad(Z, 0.5, -tmp);
	} else {
		float tmp = sqrt(ZZ_fE);
		H = (Z + tmp) * 0.5;
		h = (Z - tmp) * 0.5;

		tmp = (B*Z - 2.0*D) / (2.0*tmp);
		G = mad(B, 0.5, tmp);
		g = mad(B, 0.5, -tmp);
	}
	// Solve the quadratics
	return float4(solveQuadratic(float3(1.0, G, H)), solveQuadratic(float3(1.0, g, h)));
}

/*! Definition of utility functions for quantization and dequantization of 
	power moments stored in 16 bits per moment. */
void offsetMoments(inout float2 b_even, inout float2 b_odd, float sign)
{
	b_odd += 0.5 * sign;
}

void quantizeMoments(out float2 b_even_q, out float2 b_odd_q, float2 b_even, float2 b_odd)
{
	b_odd_q = mul(b_odd, float2x2(1.5f, sqrt(3.0f)*0.5f, -2.0f, -sqrt(3.0f)*2.0f / 9.0f));
	b_even_q = mul(b_even, float2x2(4.0f, 0.5f, -4.0f, 0.5f));
}

void offsetAndDequantizeMoments(out float2 b_even, out float2 b_odd, float2 b_even_q, float2 b_odd_q)
{
	offsetMoments(b_even_q, b_odd_q, -1.0);
	b_odd = mul(b_odd_q, float2x2(-1.0f / 3.0f, -0.75f, sqrt(3.0f), 0.75f*sqrt(3.0f)));
	b_even = mul(b_even_q, float2x2(0.125f, -0.125f, 1.0f, 1.0f));
}

void offsetMoments(inout float3 b_even, inout float3 b_odd, float sign)
{
	b_odd += 0.5 * sign;
	b_even.z += 0.018888946f * sign;
}

void quantizeMoments(out float3 b_even_q, out float3 b_odd_q, float3 b_even, float3 b_odd)
{
	const float3x3 QuantizationMatrixOdd = float3x3(
		2.5f, -1.87499864450f, 1.26583039016f,
		-10.0f, 4.20757543111f, -1.47644882902f,
		8.0f, -1.83257678661f, 0.71061660238f);
	const float3x3 QuantizationMatrixEven = float3x3(
		4.0f, 9.0f, -0.57759806484f,
		-4.0f, -24.0f, 4.61936647543f,
		0.0f, 16.0f, -3.07953906655f);
	b_odd_q = mul(b_odd, QuantizationMatrixOdd);
	b_even_q = mul(b_even, QuantizationMatrixEven);
}

void offsetAndDequantizeMoments(out float3 b_even, out float3 b_odd, float3 b_even_q, float3 b_odd_q)
{
	const float3x3 QuantizationMatrixOdd = float3x3(
		-0.02877789192f, 0.09995235706f, 0.25893353755f,
		0.47635550422f, 0.84532580931f, 0.90779616657f,
		1.55242808973f, 1.05472570761f, 0.83327335647f);
	const float3x3 QuantizationMatrixEven = float3x3(
		0.00001253044f, -0.24998746956f, -0.37498825271f,
		0.16668494186f, 0.16668494186f, 0.21876713299f,
		0.86602540579f, 0.86602540579f, 0.81189881793f);
	offsetMoments(b_even_q, b_odd_q, -1.0);
	b_odd = mul(b_odd_q, QuantizationMatrixOdd);
	b_even = mul(b_even_q, QuantizationMatrixEven);
}

void offsetMoments(inout float4 b_even, inout float4 b_odd, float sign)
{
	b_odd += 0.5 * sign;
	b_even += float4(0.972481993925964, 1.0, 0.999179192513328, 0.991778293073131) * sign;
}

void quantizeMoments(out float4 b_even_q, out float4 b_odd_q, float4 b_even, float4 b_odd)
{
	const float4x4 mat_odd = float4x4(3.48044635732474, -27.5760737514826, 55.1267384344761, -31.5311110403183,
		1.26797185782836, -0.928755808743913, -2.07520453231032, 1.23598848322588,
		-2.1671560004294, 6.17950199592966, -0.276515571579297, -4.23583042392097,
		0.974332879165755, -0.443426830933027, -0.360491648368785, 0.310149466050223);
	const float4x4 mat_even = float4x4(0.280504133158527, -0.757633844606942, 0.392179589334688, -0.887531871812237,
		-2.01362265883247, 0.221551373038988, -1.06107954265125, 2.83887201588367,
		-7.31010494985321, 13.9855979699139, -0.114305766176437, -7.4361899359832,
		-15.8954215629556, 79.6186327084103, -127.457278992502, 63.7349456687829);
	b_odd_q = mul(mat_odd, b_odd);
	b_even_q = mul(mat_even, b_even);
}

void offsetAndDequantizeMoments(out float4 b_even, out float4 b_odd, float4 b_even_q, float4 b_odd_q)
{
	const float4x4 mat_odd = float4x4(-0.00482399708502382, -0.423201508674231, 0.0348312382605129, 1.67179208266592,
		-0.0233402218644408, -0.832829097046478, 0.0193406040499625, 1.21021509068975,
		-0.010888537031885, -0.926393772997063, -0.11723394414779, 0.983723301818275,
		-0.0308713357806732, -0.937989172670245, -0.218033377677099, 0.845991731322996);
	const float4x4 mat_even = float4x4(-0.976220278891035, -0.456139260269401, -0.0504335521016742, 0.000838800390651085,
		-1.04828341778299, -0.229726640510149, 0.0259608334616091, -0.00133632693205861,
		-1.03115268628604, -0.077844420809897, 0.00443408851014257, -0.0103744938457406,
		-0.996038443434636, 0.0175438624416783, -0.0361414253243963, -0.00317839994022725);
	offsetMoments(b_even_q, b_odd_q, -1.0);
	b_odd = mul(mat_odd, b_odd_q);
	b_even = mul(mat_even, b_even_q);
}

/*! This function reconstructs the transmittance at the given depth from four 
	normalized power moments and the given zeroth moment.*/
float computeTransmittanceAtDepthFrom4PowerMoments(float b_0, float2 b_even, float2 b_odd, float depth, float bias, float overestimation, float4 bias_vector)
{
	float4 b = float4(b_odd.x, b_even.x, b_odd.y, b_even.y);
	// Bias input data to avoid artifacts
	b = lerp(b, bias_vector, bias);
	float3 z;
	z[0] = depth;

	// Compute a Cholesky factorization of the Hankel matrix B storing only non-
	// trivial entries or related products
	float L21D11=mad(-b[0],b[1],b[2]);
	float D11=mad(-b[0],b[0], b[1]);
	float InvD11=1.0f/D11;
	float L21=L21D11*InvD11;
	float SquaredDepthVariance=mad(-b[1],b[1], b[3]);
	float D22=mad(-L21D11,L21,SquaredDepthVariance);

	// Obtain a scaled inverse image of bz=(1,z[0],z[0]*z[0])^T
	float3 c=float3(1.0f,z[0],z[0]*z[0]);
	// Forward substitution to solve L*c1=bz
	c[1]-=b.x;
	c[2]-=b.y+L21*c[1];
	// Scaling to solve D*c2=c1
	c[1]*=InvD11;
	c[2]/=D22;
	// Backward substitution to solve L^T*c3=c2
	c[1]-=L21*c[2];
	c[0]-=dot(c.yz,b.xy);
	// Solve the quadratic equation c[0]+c[1]*z+c[2]*z^2 to obtain solutions 
	// z[1] and z[2]
	float InvC2=1.0f/c[2];
	float p=c[1]*InvC2;
	float q=c[0]*InvC2;
	float D=(p*p*0.25f)-q;
	float r=sqrt(D);
	z[1]=-p*0.5f-r;
	z[2]=-p*0.5f+r;
	// Compute the absorbance by summing the appropriate weights
	float3 polynomial;
	float3 weight_factor = float3(overestimation, (z[1] < z[0])?1.0f:0.0f, (z[2] < z[0])?1.0f:0.0f);
	float f0=weight_factor[0];
	float f1=weight_factor[1];
	float f2=weight_factor[2];
	float f01=(f1-f0)/(z[1]-z[0]);
	float f12=(f2-f1)/(z[2]-z[1]);
	float f012=(f12-f01)/(z[2]-z[0]);
	polynomial[0]=f012;
	polynomial[1]=polynomial[0];
	polynomial[0]=f01-polynomial[0]*z[1];
	polynomial[2]=polynomial[1];
	polynomial[1]=polynomial[0]-polynomial[1]*z[0];
	polynomial[0]=f0-polynomial[0]*z[0];
	float absorbance = polynomial[0] + dot(b.xy, polynomial.yz);;
	// Turn the normalized absorbance into transmittance
	return saturate(exp(-b_0 * absorbance));
}

/*! This function reconstructs the transmittance at the given depth from six 
	normalized power moments and the given zeroth moment.*/
float computeTransmittanceAtDepthFrom6PowerMoments(float b_0, float3 b_even, float3 b_odd, float depth, float bias, float overestimation, float bias_vector[6])
{
	float b[6] = { b_odd.x, b_even.x, b_odd.y, b_even.y, b_odd.z, b_even.z };
	// Bias input data to avoid artifacts
	[unroll] for (int i = 0; i != 6; ++i) {
		b[i] = lerp(b[i], bias_vector[i], bias);
	}

	float4 z;
	z[0] = depth;

	// Compute a Cholesky factorization of the Hankel matrix B storing only non-
	// trivial entries or related products
	float InvD11 = 1.0f / mad(-b[0], b[0], b[1]);
	float L21D11 = mad(-b[0], b[1], b[2]);
	float L21 = L21D11*InvD11;
	float D22 = mad(-L21D11, L21, mad(-b[1], b[1], b[3]));
	float L31D11 = mad(-b[0], b[2], b[3]);
	float L31 = L31D11*InvD11;
	float InvD22 = 1.0f / D22;
	float L32D22 = mad(-L21D11, L31, mad(-b[1], b[2], b[4]));
	float L32 = L32D22*InvD22;
	float D33 = mad(-b[2], b[2], b[5]) - dot(float2(L31D11, L32D22), float2(L31, L32));
	float InvD33 = 1.0f / D33;

	// Construct the polynomial whose roots have to be points of support of the 
	// canonical distribution: bz=(1,z[0],z[0]*z[0],z[0]*z[0]*z[0])^T
	float4 c;
	c[0] = 1.0f;
	c[1] = z[0];
	c[2] = c[1] * z[0];
	c[3] = c[2] * z[0];
	// Forward substitution to solve L*c1=bz
	c[1] -= b[0];
	c[2] -= mad(L21, c[1], b[1]);
	c[3] -= b[2] + dot(float2(L31, L32), c.yz);
	// Scaling to solve D*c2=c1
	c.yzw *= float3(InvD11, InvD22, InvD33);
	// Backward substitution to solve L^T*c3=c2
	c[2] -= L32*c[3];
	c[1] -= dot(float2(L21, L31), c.zw);
	c[0] -= dot(float3(b[0], b[1], b[2]), c.yzw);

	// Solve the cubic equation
	z.yzw = SolveCubic(c);

	// Compute the absorbance by summing the appropriate weights
	float4 weigth_factor;
	weigth_factor[0] = overestimation;
	weigth_factor.yzw = (z.yzw > z.xxx) ? float3 (0.0f, 0.0f, 0.0f) : float3 (1.0f, 1.0f, 1.0f);
	// Construct an interpolation polynomial
	float f0 = weigth_factor[0];
	float f1 = weigth_factor[1];
	float f2 = weigth_factor[2];
	float f3 = weigth_factor[3];
	float f01 = (f1 - f0) / (z[1] - z[0]);
	float f12 = (f2 - f1) / (z[2] - z[1]);
	float f23 = (f3 - f2) / (z[3] - z[2]);
	float f012 = (f12 - f01) / (z[2] - z[0]);
	float f123 = (f23 - f12) / (z[3] - z[1]);
	float f0123 = (f123 - f012) / (z[3] - z[0]);
	float4 polynomial;
	// f012+f0123 *(z-z2)
	polynomial[0] = mad(-f0123, z[2], f012);
	polynomial[1] = f0123;
	// *(z-z1) +f01
	polynomial[2] = polynomial[1];
	polynomial[1] = mad(polynomial[1], -z[1], polynomial[0]);
	polynomial[0] = mad(polynomial[0], -z[1], f01);
	// *(z-z0) +f0
	polynomial[3] = polynomial[2];
	polynomial[2] = mad(polynomial[2], -z[0], polynomial[1]);
	polynomial[1] = mad(polynomial[1], -z[0], polynomial[0]);
	polynomial[0] = mad(polynomial[0], -z[0], f0);
	float absorbance = dot(polynomial, float4 (1.0, b[0], b[1], b[2]));
	// Turn the normalized absorbance into transmittance
	return saturate(exp(-b_0 * absorbance));
}

/*! This function reconstructs the transmittance at the given depth from eight 
	normalized power moments and the given zeroth moment.*/
float computeTransmittanceAtDepthFrom8PowerMoments(float b_0, float4 b_even, float4 b_odd, float depth, float bias, float overestimation, float bias_vector[8])
{
	float b[8] = { b_odd.x, b_even.x, b_odd.y, b_even.y, b_odd.z, b_even.z, b_odd.w, b_even.w };
	// Bias input data to avoid artifacts
	[unroll] for (int i = 0; i != 8; ++i) {
		b[i] = lerp(b[i], bias_vector[i], bias);
	}

	float z[5];
	z[0] = depth;

	// Compute a Cholesky factorization of the Hankel matrix B storing only non-trivial entries or related products
	float D22 = mad(-b[0], b[0], b[1]);
	float InvD22 = 1.0 / D22;
	float L32D22 = mad(-b[1], b[0], b[2]);
	float L32 = L32D22 * InvD22;
	float L42D22 = mad(-b[2], b[0], b[3]);
	float L42 = L42D22 * InvD22;
	float L52D22 = mad(-b[3], b[0], b[4]);
	float L52 = L52D22 * InvD22;

	float D33 = mad(-L32, L32D22, mad(-b[1], b[1], b[3]));
	float InvD33 = 1.0 / D33;
	float L43D33 = mad(-L42, L32D22, mad(-b[2], b[1], b[4]));
	float L43 = L43D33 * InvD33;
	float L53D33 = mad(-L52, L32D22, mad(-b[3], b[1], b[5]));
	float L53 = L53D33 * InvD33;

	float D44 = mad(-b[2], b[2], b[5]) - dot(float2(L42, L43), float2(L42D22, L43D33));
	float InvD44 = 1.0 / D44;
	float L54D44 = mad(-b[3], b[2], b[6]) - dot(float2(L52, L53), float2(L42D22, L43D33));
	float L54 = L54D44 * InvD44;

	float D55 = mad(-b[3], b[3], b[7]) - dot(float3(L52, L53, L54), float3(L52D22, L53D33, L54D44));
	float InvD55 = 1.0 / D55;

	// Construct the polynomial whose roots have to be points of support of the
	// Canonical distribution:
	// bz = (1,z[0],z[0]^2,z[0]^3,z[0]^4)^T
	float c[5];
	c[0] = 1.0;
	c[1] = z[0];
	c[2] = c[1] * z[0];
	c[3] = c[2] * z[0];
	c[4] = c[3] * z[0];

	// Forward substitution to solve L*c1 = bz
	c[1] -= b[0];
	c[2] -= mad(L32, c[1], b[1]);
	c[3] -= b[2] + dot(float2(L42, L43), float2(c[1], c[2]));
	c[4] -= b[3] + dot(float3(L52, L53, L54), float3(c[1], c[2], c[3]));

	// Scaling to solve D*c2 = c1
	//c = c .*[1, InvD22, InvD33, InvD44, InvD55];
	c[1] *= InvD22;
	c[2] *= InvD33;
	c[3] *= InvD44;
	c[4] *= InvD55;

	// Backward substitution to solve L^T*c3 = c2
	c[3] -= L54 * c[4];
	c[2] -= dot(float2(L53, L43), float2(c[4], c[3]));
	c[1] -= dot(float3(L52, L42, L32), float3(c[4], c[3], c[2]));
	c[0] -= dot(float4(b[3], b[2], b[1], b[0]), float4(c[4], c[3], c[2], c[1]));

	// Solve the quartic equation
	float4 zz = solveQuarticNeumark(c);
	z[1] = zz[0];
	z[2] = zz[1];
	z[3] = zz[2];
	z[4] = zz[3];

	// Compute the absorbance by summing the appropriate weights
	float4 weigth_factor = (float4(z[1], z[2], z[3], z[4]) <= z[0].xxxx);
	// Construct an interpolation polynomial
	float f0 = overestimation;
	float f1 = weigth_factor[0];
	float f2 = weigth_factor[1];
	float f3 = weigth_factor[2];
	float f4 = weigth_factor[3];
	float f01 = (f1 - f0) / (z[1] - z[0]);
	float f12 = (f2 - f1) / (z[2] - z[1]);
	float f23 = (f3 - f2) / (z[3] - z[2]);
	float f34 = (f4 - f3) / (z[4] - z[3]);
	float f012 = (f12 - f01) / (z[2] - z[0]);
	float f123 = (f23 - f12) / (z[3] - z[1]);
	float f234 = (f34 - f23) / (z[4] - z[2]);
	float f0123 = (f123 - f012) / (z[3] - z[0]);
	float f1234 = (f234 - f123) / (z[4] - z[1]);
	float f01234 = (f1234 - f0123) / (z[4] - z[0]);

	float Polynomial_0;
	float4 Polynomial;
	// f0123 + f01234 * (z - z3)
	Polynomial_0 = mad(-f01234, z[3], f0123);
	Polynomial[0] = f01234;
	// * (z - z2) + f012
	Polynomial[1] = Polynomial[0];
	Polynomial[0] = mad(-Polynomial[0], z[2], Polynomial_0);
	Polynomial_0 = mad(-Polynomial_0, z[2], f012);
	// * (z - z1) + f01
	Polynomial[2] = Polynomial[1];
	Polynomial[1] = mad(-Polynomial[1], z[1], Polynomial[0]);
	Polynomial[0] = mad(-Polynomial[0], z[1], Polynomial_0);
	Polynomial_0 = mad(-Polynomial_0, z[1], f01);
	// * (z - z0) + f1
	Polynomial[3] = Polynomial[2];
	Polynomial[2] = mad(-Polynomial[2], z[0], Polynomial[1]);
	Polynomial[1] = mad(-Polynomial[1], z[0], Polynomial[0]);
	Polynomial[0] = mad(-Polynomial[0], z[0], Polynomial_0);
	Polynomial_0 = mad(-Polynomial_0, z[0], f0);
	float absorbance = Polynomial_0 + dot(Polynomial, float4(b[0], b[1], b[2], b[3]));
	// Turn the normalized absorbance into transmittance
	return saturate(exp(-b_0 * absorbance));
}

#endif