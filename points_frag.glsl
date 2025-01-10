uniform vec3 diffuse;
uniform float opacity;
//
//#include <common>
//
#define PI 3.141592653589793
#define PI2 6.283185307179586
#define PI_HALF 1.5707963267948966
#define RECIPROCAL_PI 0.3183098861837907
#define RECIPROCAL_PI2 0.15915494309189535
#define EPSILON 1e-6

#ifndef saturate
// <tonemapping_pars_fragment> may have defined saturate() already
#define saturate( a ) clamp( a, 0.0, 1.0 )
#endif
#define whiteComplement( a ) ( 1.0 - saturate( a ) )

float pow2( const in float x ) { return x*x; }
vec3 pow2( const in vec3 x ) { return x*x; }
float pow3( const in float x ) { return x*x*x; }
float pow4( const in float x ) { float x2 = x*x; return x2*x2; }
float max3( const in vec3 v ) { return max( max( v.x, v.y ), v.z ); }
float average( const in vec3 v ) { return dot( v, vec3( 0.3333333 ) ); }

// expects values in the range of [0,1]x[0,1], returns values in the [0,1] range.
// do not collapse into a single function per: http://byteblacksmith.com/improvements-to-the-canonical-one-liner-glsl-rand-for-opengl-es-2-0/
highp float rand( const in vec2 uv ) {

	const highp float a = 12.9898, b = 78.233, c = 43758.5453;
	highp float dt = dot( uv.xy, vec2( a,b ) ), sn = mod( dt, PI );

	return fract( sin( sn ) * c );

}

#ifdef HIGH_PRECISION
	float precisionSafeLength( vec3 v ) { return length( v ); }
#else
	float precisionSafeLength( vec3 v ) {
		float maxComponent = max3( abs( v ) );
		return length( v / maxComponent ) * maxComponent;
	}
#endif

struct IncidentLight {
	vec3 color;
	vec3 direction;
	bool visible;
};

struct ReflectedLight {
	vec3 directDiffuse;
	vec3 directSpecular;
	vec3 indirectDiffuse;
	vec3 indirectSpecular;
};

#ifdef USE_ALPHAHASH

	varying vec3 vPosition;

#endif

vec3 transformDirection( in vec3 dir, in mat4 matrix ) {

	return normalize( ( matrix * vec4( dir, 0.0 ) ).xyz );

}

vec3 inverseTransformDirection( in vec3 dir, in mat4 matrix ) {

	// dir can be either a direction vector or a normal vector
	// upper-left 3x3 of matrix is assumed to be orthogonal

	return normalize( ( vec4( dir, 0.0 ) * matrix ).xyz );

}

mat3 transposeMat3( const in mat3 m ) {

	mat3 tmp;

	tmp[ 0 ] = vec3( m[ 0 ].x, m[ 1 ].x, m[ 2 ].x );
	tmp[ 1 ] = vec3( m[ 0 ].y, m[ 1 ].y, m[ 2 ].y );
	tmp[ 2 ] = vec3( m[ 0 ].z, m[ 1 ].z, m[ 2 ].z );

	return tmp;

}

bool isPerspectiveMatrix( mat4 m ) {

	return m[ 2 ][ 3 ] == - 1.0;

}

vec2 equirectUv( in vec3 dir ) {

	// dir is assumed to be unit length

	float u = atan( dir.z, dir.x ) * RECIPROCAL_PI2 + 0.5;

	float v = asin( clamp( dir.y, - 1.0, 1.0 ) ) * RECIPROCAL_PI + 0.5;

	return vec2( u, v );

}

vec3 BRDF_Lambert( const in vec3 diffuseColor ) {

	return RECIPROCAL_PI * diffuseColor;

} // validated

vec3 F_Schlick( const in vec3 f0, const in float f90, const in float dotVH ) {

	// Original approximation by Christophe Schlick '94
	// float fresnel = pow( 1.0 - dotVH, 5.0 );

	// Optimized variant (presented by Epic at SIGGRAPH '13)
	// https://cdn2.unrealengine.com/Resources/files/2013SiggraphPresentationsNotes-26915738.pdf
	float fresnel = exp2( ( - 5.55473 * dotVH - 6.98316 ) * dotVH );

	return f0 * ( 1.0 - fresnel ) + ( f90 * fresnel );

} // validated

float F_Schlick( const in float f0, const in float f90, const in float dotVH ) {

	// Original approximation by Christophe Schlick '94
	// float fresnel = pow( 1.0 - dotVH, 5.0 );

	// Optimized variant (presented by Epic at SIGGRAPH '13)
	// https://cdn2.unrealengine.com/Resources/files/2013SiggraphPresentationsNotes-26915738.pdf
	float fresnel = exp2( ( - 5.55473 * dotVH - 6.98316 ) * dotVH );

	return f0 * ( 1.0 - fresnel ) + ( f90 * fresnel );

} // validated

//
//#include <color_pars_fragment>
//
#if defined( USE_COLOR_ALPHA )

	varying vec4 vColor;

#elif defined( USE_COLOR )

	varying vec3 vColor;

#endif

//
//#include <map_particle_pars_fragment>
//
#if defined( USE_POINTS_UV )

	varying vec2 vUv;

#else

	#if defined( USE_MAP ) || defined( USE_ALPHAMAP )

		uniform mat3 uvTransform;

	#endif

#endif

#ifdef USE_MAP

	uniform sampler2D map;

#endif

#ifdef USE_ALPHAMAP

	uniform sampler2D alphaMap;

#endif

//
//#include <alphatest_pars_fragment>
//
#ifdef USE_ALPHATEST
	uniform float alphaTest;
#endif

//
//#include <alphahash_pars_fragment>
//
#ifdef USE_ALPHAHASH

	/**
	 * See: https://casual-effects.com/research/Wyman2017Hashed/index.html
	 */

	const float ALPHA_HASH_SCALE = 0.05; // Derived from trials only, and may be changed.

	float hash2D( vec2 value ) {

		return fract( 1.0e4 * sin( 17.0 * value.x + 0.1 * value.y ) * ( 0.1 + abs( sin( 13.0 * value.y + value.x ) ) ) );

	}

	float hash3D( vec3 value ) {

		return hash2D( vec2( hash2D( value.xy ), value.z ) );

	}

	float getAlphaHashThreshold( vec3 position ) {

		// Find the discretized derivatives of our coordinates
		float maxDeriv = max(
			length( dFdx( position.xyz ) ),
			length( dFdy( position.xyz ) )
		);
		float pixScale = 1.0 / ( ALPHA_HASH_SCALE * maxDeriv );

		// Find two nearest log-discretized noise scales
		vec2 pixScales = vec2(
			exp2( floor( log2( pixScale ) ) ),
			exp2( ceil( log2( pixScale ) ) )
		);

		// Compute alpha thresholds at our two noise scales
		vec2 alpha = vec2(
			hash3D( floor( pixScales.x * position.xyz ) ),
			hash3D( floor( pixScales.y * position.xyz ) )
		);

		// Factor to interpolate lerp with
		float lerpFactor = fract( log2( pixScale ) );

		// Interpolate alpha threshold from noise at two scales
		float x = ( 1.0 - lerpFactor ) * alpha.x + lerpFactor * alpha.y;

		// Pass into CDF to compute uniformly distrib threshold
		float a = min( lerpFactor, 1.0 - lerpFactor );
		vec3 cases = vec3(
			x * x / ( 2.0 * a * ( 1.0 - a ) ),
			( x - 0.5 * a ) / ( 1.0 - a ),
			1.0 - ( ( 1.0 - x ) * ( 1.0 - x ) / ( 2.0 * a * ( 1.0 - a ) ) )
		);

		// Find our final, uniformly distributed alpha threshold (ατ)
		float threshold = ( x < ( 1.0 - a ) )
			? ( ( x < a ) ? cases.x : cases.y )
			: cases.z;

		// Avoids ατ == 0. Could also do ατ =1-ατ
		return clamp( threshold , 1.0e-6, 1.0 );

	}

#endif

//
//#include <fog_pars_fragment>
//
#ifdef USE_FOG

	uniform vec3 fogColor;
	varying float vFogDepth;

	#ifdef FOG_EXP2

		uniform float fogDensity;

	#else

		uniform float fogNear;
		uniform float fogFar;

	#endif

#endif

//
//#include <logdepthbuf_pars_fragment>
//
#if defined( USE_LOGDEPTHBUF )

	uniform float logDepthBufFC;
	varying float vFragDepth;
	varying float vIsPerspective;

#endif

//
//#include <clipping_planes_pars_fragment>
//
#if NUM_CLIPPING_PLANES > 0

	varying vec3 vClipPosition;

	uniform vec4 clippingPlanes[ NUM_CLIPPING_PLANES ];

#endif

void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	//<<
    //#include <clipping_planes_fragment>
    //
        #if NUM_CLIPPING_PLANES > 0

            vec4 plane;

            #ifdef ALPHA_TO_COVERAGE

                float distanceToPlane, distanceGradient;
                float clipOpacity = 1.0;

                #pragma unroll_loop_start
                for ( int i = 0; i < UNION_CLIPPING_PLANES; i ++ ) {

                    plane = clippingPlanes[ i ];
                    distanceToPlane = - dot( vClipPosition, plane.xyz ) + plane.w;
                    distanceGradient = fwidth( distanceToPlane ) / 2.0;
                    clipOpacity *= smoothstep( - distanceGradient, distanceGradient, distanceToPlane );

                    if ( clipOpacity == 0.0 ) discard;

                }
                #pragma unroll_loop_end

                #if UNION_CLIPPING_PLANES < NUM_CLIPPING_PLANES

                    float unionClipOpacity = 1.0;

                    #pragma unroll_loop_start
                    for ( int i = UNION_CLIPPING_PLANES; i < NUM_CLIPPING_PLANES; i ++ ) {

                        plane = clippingPlanes[ i ];
                        distanceToPlane = - dot( vClipPosition, plane.xyz ) + plane.w;
                        distanceGradient = fwidth( distanceToPlane ) / 2.0;
                        unionClipOpacity *= 1.0 - smoothstep( - distanceGradient, distanceGradient, distanceToPlane );

                    }
                    #pragma unroll_loop_end

                    clipOpacity *= 1.0 - unionClipOpacity;

                #endif

                diffuseColor.a *= clipOpacity;

                if ( diffuseColor.a == 0.0 ) discard;

            #else

                #pragma unroll_loop_start
                for ( int i = 0; i < UNION_CLIPPING_PLANES; i ++ ) {

                    plane = clippingPlanes[ i ];
                    if ( dot( vClipPosition, plane.xyz ) > plane.w ) discard;

                }
                #pragma unroll_loop_end

                #if UNION_CLIPPING_PLANES < NUM_CLIPPING_PLANES

                    bool clipped = true;

                    #pragma unroll_loop_start
                    for ( int i = UNION_CLIPPING_PLANES; i < NUM_CLIPPING_PLANES; i ++ ) {

                        plane = clippingPlanes[ i ];
                        clipped = ( dot( vClipPosition, plane.xyz ) > plane.w ) && clipped;

                    }
                    #pragma unroll_loop_end

                    if ( clipped ) discard;

                #endif

            #endif

        #endif
    //>>
	vec3 outgoingLight = vec3( 0.0 );
	//<<
    //#include <logdepthbuf_fragment>
    //
        #if defined( USE_LOGDEPTHBUF )

            // Doing a strict comparison with == 1.0 can cause noise artifacts
            // on some platforms. See issue #17623.
            gl_FragDepth = vIsPerspective == 0.0 ? gl_FragCoord.z : log2( vFragDepth ) * logDepthBufFC * 0.5;

        #endif
    //>>    
	//<<
    //#include <map_particle_fragment>
    //
        #if defined( USE_MAP ) || defined( USE_ALPHAMAP )

            #if defined( USE_POINTS_UV )

                vec2 uv = vUv;

            #else

                vec2 uv = ( uvTransform * vec3( gl_PointCoord.x, 1.0 - gl_PointCoord.y, 1 ) ).xy;

            #endif

        #endif

        #ifdef USE_MAP

            diffuseColor *= texture2D( map, uv );

        #endif

        #ifdef USE_ALPHAMAP

            diffuseColor.a *= texture2D( alphaMap, uv ).g;

        #endif
    //>>
	//<<
    //#include <color_fragment>
    //
        #if defined( USE_COLOR_ALPHA )

            diffuseColor *= vColor;

        #elif defined( USE_COLOR )

            diffuseColor.rgb *= vColor;

        #endif
    //>>
	//<<
    //#include <alphatest_fragment>
    //
        #ifdef USE_ALPHATEST

            #ifdef ALPHA_TO_COVERAGE

            diffuseColor.a = smoothstep( alphaTest, alphaTest + fwidth( diffuseColor.a ), diffuseColor.a );
            if ( diffuseColor.a == 0.0 ) discard;

            #else

            if ( diffuseColor.a < alphaTest ) discard;

            #endif

        #endif
    //>>
	//<<
    //#include <alphahash_fragment>
    //
        #ifdef USE_ALPHAHASH

            if ( diffuseColor.a < getAlphaHashThreshold( vPosition ) ) discard;

        #endif
    //>>
	outgoingLight = diffuseColor.rgb;
	//<<
    //#include <opaque_fragment>
    //
        #ifdef OPAQUE
        diffuseColor.a = 1.0;
        #endif

        #ifdef USE_TRANSMISSION
        diffuseColor.a *= material.transmissionAlpha;
        #endif

        gl_FragColor = vec4( outgoingLight, diffuseColor.a );
    //>>
	//<<
    //#include <tonemapping_fragment>
    //
        #if defined( TONE_MAPPING )

            gl_FragColor.rgb = toneMapping( gl_FragColor.rgb );

        #endif
    //>>
	//<<
    //#include <colorspace_fragment>
    //
        gl_FragColor = linearToOutputTexel( gl_FragColor );
    //>>
	//<<
    //#include <fog_fragment>
    //
        #ifdef USE_FOG

            #ifdef FOG_EXP2

                float fogFactor = 1.0 - exp( - fogDensity * fogDensity * vFogDepth * vFogDepth );

            #else

                float fogFactor = smoothstep( fogNear, fogFar, vFogDepth );

            #endif

            gl_FragColor.rgb = mix( gl_FragColor.rgb, fogColor, fogFactor );

        #endif
    //>>
	//<<
    //#include <premultiplied_alpha_fragment>
    //
        #ifdef PREMULTIPLIED_ALPHA

            // Get get normal blending with premultipled, use with CustomBlending, OneFactor, OneMinusSrcAlphaFactor, AddEquation.
            gl_FragColor.rgb *= gl_FragColor.a;

        #endif
    //>>
}