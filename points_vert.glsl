//pre
uniform mat4 modelMatrix;
uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
//uniform mat4 viewMatrix;
uniform mat3 normalMatrix;
//uniform vec3 cameraPosition;
//uniform bool isOrthographic;


uniform float size;
uniform float scale;
// #include <common>
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
//#include <color_pars_vertex>
//
#if defined( USE_COLOR_ALPHA )

	varying vec4 vColor;

#elif defined( USE_COLOR ) || defined( USE_INSTANCING_COLOR ) || defined( USE_BATCHING_COLOR )

	varying vec3 vColor;

#endif

//
//#include <fog_pars_vertex>
//
#ifdef USE_FOG

	varying float vFogDepth;

#endif

//
//#include <morphtarget_pars_vertex>
//
#ifdef USE_MORPHTARGETS

	#ifndef USE_INSTANCING_MORPH

		uniform float morphTargetBaseInfluence;
		uniform float morphTargetInfluences[ MORPHTARGETS_COUNT ];

	#endif

	uniform sampler2DArray morphTargetsTexture;
	uniform ivec2 morphTargetsTextureSize;

	vec4 getMorph( const in int vertexIndex, const in int morphTargetIndex, const in int offset ) {

		int texelIndex = vertexIndex * MORPHTARGETS_TEXTURE_STRIDE + offset;
		int y = texelIndex / morphTargetsTextureSize.x;
		int x = texelIndex - y * morphTargetsTextureSize.x;

		ivec3 morphUV = ivec3( x, y, morphTargetIndex );
		return texelFetch( morphTargetsTexture, morphUV, 0 );

	}

#endif

//
//#include <logdepthbuf_pars_vertex>
//
#ifdef USE_LOGDEPTHBUF

	varying float vFragDepth;
	varying float vIsPerspective;

#endif


//
//#include <clipping_planes_pars_vertex>
//
#if NUM_CLIPPING_PLANES > 0

	varying vec3 vClipPosition;

#endif


#ifdef USE_POINTS_UV
	varying vec2 vUv;
	uniform mat3 uvTransform;
#endif
void main() {
	#ifdef USE_POINTS_UV
		vUv = ( uvTransform * vec3( uv, 1 ) ).xy;
	#endif
	//#include <color_vertex>
    #if defined( USE_COLOR_ALPHA )

        vColor = vec4( 1.0 );

    #elif defined( USE_COLOR ) || defined( USE_INSTANCING_COLOR ) || defined( USE_BATCHING_COLOR )

        vColor = vec3( 1.0 );

    #endif

    #ifdef USE_COLOR

        vColor *= color;

    #endif

    #ifdef USE_INSTANCING_COLOR

        vColor.xyz *= instanceColor.xyz;

    #endif

    #ifdef USE_BATCHING_COLOR

        vec3 batchingColor = getBatchingColor( getIndirectIndex( gl_DrawID ) );

        vColor.xyz *= batchingColor.xyz;

    #endif

	//#include <morphinstance_vertex>
    #ifdef USE_INSTANCING_MORPH

        float morphTargetInfluences[ MORPHTARGETS_COUNT ];

        float morphTargetBaseInfluence = texelFetch( morphTexture, ivec2( 0, gl_InstanceID ), 0 ).r;

        for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {

            morphTargetInfluences[i] =  texelFetch( morphTexture, ivec2( i + 1, gl_InstanceID ), 0 ).r;

        }
    #endif

	//#include <morphcolor_vertex>
    #if defined( USE_MORPHCOLORS )

        // morphTargetBaseInfluence is set based on BufferGeometry.morphTargetsRelative value:
        // When morphTargetsRelative is false, this is set to 1 - sum(influences); this results in normal = sum((target - base) * influence)
        // When morphTargetsRelative is true, this is set to 1; as a result, all morph targets are simply added to the base after weighting
        vColor *= morphTargetBaseInfluence;

        for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {

            #if defined( USE_COLOR_ALPHA )

                if ( morphTargetInfluences[ i ] != 0.0 ) vColor += getMorph( gl_VertexID, i, 2 ) * morphTargetInfluences[ i ];

            #elif defined( USE_COLOR )

                if ( morphTargetInfluences[ i ] != 0.0 ) vColor += getMorph( gl_VertexID, i, 2 ).rgb * morphTargetInfluences[ i ];

            #endif

        }

    #endif
    
	//#include <begin_vertex>
    vec3 transformed = vec3( position );

    #ifdef USE_ALPHAHASH

        vPosition = vec3( position );

    #endif

	//#include <morphtarget_vertex>
    #ifdef USE_MORPHTARGETS

        // morphTargetBaseInfluence is set based on BufferGeometry.morphTargetsRelative value:
        // When morphTargetsRelative is false, this is set to 1 - sum(influences); this results in position = sum((target - base) * influence)
        // When morphTargetsRelative is true, this is set to 1; as a result, all morph targets are simply added to the base after weighting
        transformed *= morphTargetBaseInfluence;

        for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {

            if ( morphTargetInfluences[ i ] != 0.0 ) transformed += getMorph( gl_VertexID, i, 0 ).xyz * morphTargetInfluences[ i ];

        }

    #endif

	//#include <project_vertex>
    vec4 mvPosition = vec4( transformed, 1.0 );

    #ifdef USE_BATCHING

        mvPosition = batchingMatrix * mvPosition;

    #endif

    #ifdef USE_INSTANCING

        mvPosition = instanceMatrix * mvPosition;

    #endif

    mvPosition = modelViewMatrix * mvPosition;

    gl_Position = projectionMatrix * mvPosition;

    // point starts here
	gl_PointSize = size;
	#ifdef USE_SIZEATTENUATION
		bool isPerspective = isPerspectiveMatrix( projectionMatrix );
		if ( isPerspective ) gl_PointSize *= ( scale / - mvPosition.z );
	#endif
	//#include <logdepthbuf_vertex>
    #ifdef USE_LOGDEPTHBUF

        vFragDepth = 1.0 + gl_Position.w;
        vIsPerspective = float( isPerspectiveMatrix( projectionMatrix ) );

    #endif

	//#include <clipping_planes_vertex>
    #if NUM_CLIPPING_PLANES > 0

        vClipPosition = - mvPosition.xyz;

    #endif

	//#include <worldpos_vertex>
    #if defined( USE_ENVMAP ) || defined( DISTANCE ) || defined ( USE_SHADOWMAP ) || defined ( USE_TRANSMISSION ) || NUM_SPOT_LIGHT_COORDS > 0

        vec4 worldPosition = vec4( transformed, 1.0 );

        #ifdef USE_BATCHING

            worldPosition = batchingMatrix * worldPosition;

        #endif

        #ifdef USE_INSTANCING

            worldPosition = instanceMatrix * worldPosition;

        #endif

        worldPosition = modelMatrix * worldPosition;

    #endif

	//#include <fog_vertex>
    #ifdef USE_FOG

        vFogDepth = - mvPosition.z;

    #endif

}