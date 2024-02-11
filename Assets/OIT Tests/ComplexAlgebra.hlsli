/*! \file
   This header defines utility functions to deal with complex numbers and 
   complex polynomials.*/
#ifndef COMPLEX_ALGEBRA
#define COMPLEX_ALGEBRA

/*! Returns the complex conjugate of the given complex number (i.e. it changes 
	the sign of the y-component).*/
float2 Conjugate(float2 Z){
	return float2(Z.x,-Z.y);
}
/*! This function implements complex multiplication.*/
float2 Multiply(float2 LHS,float2 RHS){
	return float2(LHS.x*RHS.x-LHS.y*RHS.y,LHS.x*RHS.y+LHS.y*RHS.x);
}
/*! This function computes the magnitude of the given complex number.*/
float Magnitude(float2 Z){
	return sqrt(dot(Z,Z));
}
/*! This function computes the quotient of two complex numbers. The denominator 
	must not be zero.*/
float2 Divide(float2 Numerator,float2 Denominator){
	return float2(Numerator.x*Denominator.x+Numerator.y*Denominator.y,-Numerator.x*Denominator.y+Numerator.y*Denominator.x)/dot(Denominator,Denominator);
}
/*! This function divides a real number by a complex number. The denominator 
	must not be zero.*/
float2 Divide(float Numerator,float2 Denominator){
	return float2(Numerator*Denominator.x,-Numerator*Denominator.y)/dot(Denominator,Denominator);
}
/*! This function implements computation of the reciprocal of the given non-
	zero complex number.*/
float2 Reciprocal(float2 Z){
	return float2(Z.x,-Z.y)/dot(Z,Z);
}
/*! This utility function implements complex squaring.*/
float2 Square(float2 Z){
	return float2(Z.x*Z.x-Z.y*Z.y,2.0f*Z.x*Z.y);
}
/*! This utility function implements complex computation of the third power.*/
float2 Cube(float2 Z){
	return Multiply(Square(Z),Z);
}
/*! This utility function computes one square root of the given complex value. 
	The other one can be found using the unary minus operator.
  \warning This function is continuous but not defined on the negative real 
			axis (and cannot be continued continuously there).
  \sa SquareRoot() */
float2 SquareRootUnsafe(float2 Z){
	float ZLengthSq=dot(Z,Z);
	float ZLengthInv=rsqrt(ZLengthSq);
	float2 UnnormalizedRoot=Z*ZLengthInv+float2(1.0f,0.0f);
	float UnnormalizedRootLengthSq=dot(UnnormalizedRoot,UnnormalizedRoot);
	float NormalizationFactorInvSq=UnnormalizedRootLengthSq*ZLengthInv;
	float NormalizationFactor=rsqrt(NormalizationFactorInvSq);
	return NormalizationFactor*UnnormalizedRoot;
}
/*! This utility function computes one square root of the given complex value. 
	The other one can be found using the unary minus operator.
  \note This function has discontinuities for values with real part zero.
  \sa SquareRootUnsafe() */
float2 SquareRoot(float2 Z){
	float2 ZPositiveRealPart=float2(abs(Z.x),Z.y);
	float2 ComputedRoot=SquareRootUnsafe(ZPositiveRealPart);
	return (Z.x>=0.0)?ComputedRoot:ComputedRoot.yx;
}
/*! This utility function computes one cubic root of the given complex value. The 
   other roots can be found by multiplication by cubic roots of unity.
  \note This function has various discontinuities.*/
float2 CubicRoot(float2 Z){
	float Argument=atan2(Z.y,Z.x);
	float NewArgument=Argument/3.0f;
	float2 NormalizedRoot;
	sincos(NewArgument,NormalizedRoot.y,NormalizedRoot.x);
	return NormalizedRoot*pow(dot(Z,Z),1.0f/6.0f);
}

/*! @{
   Returns the complex conjugate of the given complex vector (i.e. it changes the 
   second column resp the y-component).*/
float2x2 Conjugate(float2x2 Vector){
	return float2x2(Vector[0].x,-Vector[0].y,Vector[1].x,-Vector[1].y);
}
float3x2 Conjugate(float3x2 Vector){
	return float3x2(Vector[0].x,-Vector[0].y,Vector[1].x,-Vector[1].y,Vector[2].x,-Vector[2].y);
}
float4x2 Conjugate(float4x2 Vector){
	return float4x2(Vector[0].x,-Vector[0].y,Vector[1].x,-Vector[1].y,Vector[2].x,-Vector[2].y,Vector[3].x,-Vector[3].y);
}
void Conjugate(out float2 OutConjugateVector[5],float2 Vector[5]){
	[unroll] for(int i=0;i!=5;++i){
		OutConjugateVector[i]=float2(Vector[i].x,-Vector[i].x);
	}
}
//!@}

/*! Returns the real part of a complex number as real.*/
float RealPart(float2 Z){
	return Z.x;
}

/*! Given coefficients of a quadratic polynomial A*x^2+B*x+C, this function 
	outputs its two complex roots.*/
void SolveQuadratic(out float2 pOutRoot[2],float2 A,float2 B,float2 C)
{
	// Normalize the coefficients
	float2 InvA=Reciprocal(A);
	B=Multiply(B,InvA);
	C=Multiply(C,InvA);
	// Divide the middle coefficient by two
	B*=0.5f;
	// Apply the quadratic formula
	float2 DiscriminantRoot=SquareRoot(Square(B)-C);
	pOutRoot[0]=-B-DiscriminantRoot;
	pOutRoot[1]=-B+DiscriminantRoot;
}

/*! Given coefficients of a cubic polynomial A*x^3+B*x^2+C*x+D, this function 
	outputs its three complex roots.*/
void SolveCubicBlinn(out float2 pOutRoot[3],float2 A,float2 B,float2 C,float2 D)
{
	// Normalize the polynomial
	float2 InvA=Reciprocal(A);
	B=Multiply(B,InvA);
	C=Multiply(C,InvA);
	D=Multiply(D,InvA);
	// Divide middle coefficients by three
	B/=3.0f;
	C/=3.0f;
	// Compute the Hessian and the discriminant
	float2 Delta00=-Square(B)+C;
	float2 Delta01=-Multiply(C,B)+D;
	float2 Delta11=Multiply(B,D)-Square(C);
	float2 Discriminant=4.0f*Multiply(Delta00,Delta11)-Square(Delta01);
	// Compute coefficients of the depressed cubic 
	// (third is zero, fourth is one)
	float2 DepressedD=-2.0f*Multiply(B,Delta00)+Delta01;
	float2 DepressedC=Delta00;
	// Take the cubic root of a complex number avoiding cancellation
	float2 DiscriminantRoot=SquareRoot(-Discriminant);
	DiscriminantRoot=faceforward(DiscriminantRoot,DiscriminantRoot,DepressedD);
	float2 CubedRoot=DiscriminantRoot-DepressedD;
	float2 FirstRoot=CubicRoot(0.5f*CubedRoot);
	float2 pCubicRoot[3]={
		FirstRoot,
		Multiply(float2(-0.5f,-0.5f*sqrt(3.0f)),FirstRoot),
		Multiply(float2(-0.5f, 0.5f*sqrt(3.0f)),FirstRoot)
	};
	// Also compute the reciprocal cubic roots
	float2 InvFirstRoot=Reciprocal(FirstRoot);
	float2 pInvCubicRoot[3]={
		InvFirstRoot,
		Multiply(float2(-0.5f, 0.5f*sqrt(3.0f)),InvFirstRoot),
		Multiply(float2(-0.5f,-0.5f*sqrt(3.0f)),InvFirstRoot)
	};
	// Turn them into roots of the depressed cubic and revert the depression 
	// transform
	[unroll]
	for(int i=0;i!=3;++i)
	{
		pOutRoot[i]=pCubicRoot[i]-Multiply(DepressedC,pInvCubicRoot[i])-B;
	}
}


/*! Given coefficients of a quartic polynomial A*x^4+B*x^3+C*x^2+D*x+E, this 
	function outputs its four complex roots.*/
void SolveQuarticNeumark(out float2 pOutRoot[4],float2 A,float2 B,float2 C,float2 D,float2 E)
{
	// Normalize the polynomial
	float2 InvA=Reciprocal(A);
	B=Multiply(B,InvA);
	C=Multiply(C,InvA);
	D=Multiply(D,InvA);
	E=Multiply(E,InvA);
	// Construct a normalized cubic
	float2 P=-2.0f*C;
	float2 Q=Square(C)+Multiply(B,D)-4.0f*E;
	float2 R=Square(D)+Multiply(Square(B),E)-Multiply(Multiply(B,C),D);
	// Compute a root that is not the smallest of the cubic
	float2 pCubicRoot[3];
	SolveCubicBlinn(pCubicRoot,float2(1.0f,0.0f),P,Q,R);
	float2 y=(dot(pCubicRoot[1],pCubicRoot[1])>dot(pCubicRoot[0],pCubicRoot[0]))?pCubicRoot[1]:pCubicRoot[0];

	// Solve a quadratic to obtain linear coefficients for quadratic polynomials
	float2 BB=Square(B);
	float2 fy=4.0f*y;
	float2 BB_fy=BB-fy;
	float2 tmp=SquareRoot(BB_fy);
	float2 G=(B+tmp)*0.5f;
	float2 g=(B-tmp)*0.5f;
	// Construct the corresponding constant coefficients
	float2 Z=C-y;
	tmp=Divide(0.5f*Multiply(B,Z)-D,tmp);
	float2 H=Z*0.5f+tmp;
	float2 h=Z*0.5f-tmp;

	// Compute the roots
	float2 pQuadraticRoot[2];
	SolveQuadratic(pQuadraticRoot,float2(1.0f,0.0f),G,H);
	pOutRoot[0]=pQuadraticRoot[0];
	pOutRoot[1]=pQuadraticRoot[1];
	SolveQuadratic(pQuadraticRoot,float2(1.0f,0.0f),g,h);
	pOutRoot[2]=pQuadraticRoot[0];
	pOutRoot[3]=pQuadraticRoot[1];
}

#endif
