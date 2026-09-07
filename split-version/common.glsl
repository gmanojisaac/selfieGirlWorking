// https://iquilezles.org/articles/smin
float smin( float a, float b, float k )
{
    float h = max(k-abs(a-b),0.0);
    return min(a, b) - h*h*0.25/k;
}

// https://iquilezles.org/articles/smin
float smax( float a, float b, float k )
{
    k *= 1.4;
    float h = max(k-abs(a-b),0.0);
    return max(a, b) + h*h*h/(6.0*k*k);
}

// https://iquilezles.org/articles/smin
float smin3( float a, float b, float k )
{
    k *= 1.4;
    float h = max(k-abs(a-b),0.0);
    return min(a, b) - h*h*h/(6.0*k*k);
}

// https://iquilezles.org/articles/smin
float sclamp(in float x, in float a, in float b )
{
    float k = 0.1;
	return smax(smin(x,b,k),a,k);
}

// https://iquilezles.org/articles/functions/
float sabs(in float x, in float k )
{
    return sqrt(x*x+k);
}

// https://iquilezles.org/articles/distfunctions
float opOnion( in float sdf, in float thickness )
{
    return abs(sdf)-thickness;
}

// https://iquilezles.org/articles/distfunctions
float opRepLim( in float p, in float s, in float lima, in float limb )
{
    return p-s*clamp(round(p/s),lima,limb);
}

float det( vec2 a, vec2 b ) { return a.x*b.y-b.x*a.y; }
float ndot(vec2 a, vec2 b ) { return a.x*b.x-a.y*b.y; }
float dot2( in vec2 v ) { return dot(v,v); }
float dot2( in vec3 v ) { return dot(v,v); }

// https://iquilezles.org/articles/distfunctions
float sdTorus( in vec3 p, in float ra, in float rb )
{
    return length( vec2(length(p.xz)-ra,p.y) )-rb;
}

// https://iquilezles.org/articles/distfunctions
float sdCappedTorus(in vec3 p, in vec2 sc, in float ra, in float rb)
{
    p.x = abs(p.x);
    float k = (sc.y*p.x>sc.x*p.z) ? dot(p.xz,sc) : length(p.xz);
    return sqrt( dot(p,p) + ra*ra - 2.0*ra*k ) - rb;
}

// https://iquilezles.org/articles/distfunctions
float sdSphere( in vec3 p, in float r ) 
{
    return length(p)-r;
}

// https://iquilezles.org/articles/distfunctions
float sdEllipsoid( in vec3 p, in vec3 r ) 
{
    float k0 = length(p/r);
    float k1 = length(p/(r*r));
    return k0*(k0-1.0)/k1;
}

// https://iquilezles.org/articles/distfunctions
float sdBox( in vec3 p, in vec3 b )
{
    vec3 d = abs(p) - b;
    return min( max(max(d.x,d.y),d.z),0.0) + length(max(d,0.0));
}

// https://iquilezles.org/articles/distfunctions
float sdArc( in vec2 p, in vec2 scb, in float ra )
{
    p.x = abs(p.x);
    float k = (scb.y*p.x>scb.x*p.y) ? dot(p.xy,scb) : length(p.xy);
    return sqrt( dot(p,p) + ra*ra - 2.0*ra*k );
}

#if 1
// http://research.microsoft.com/en-us/um/people/hoppe/ravg.pdf
// { dist, t, y (above the plane of the curve, x (away from curve in the plane of the curve))
vec4 sdBezier( vec3 p, vec3 va, vec3 vb, vec3 vc )
{
  vec3 w = normalize( cross( vc-vb, va-vb ) );
  vec3 u = normalize( vc-vb );
  vec3 v =          ( cross( w, u ) );
  //----  
  vec2 m = vec2( dot(va-vb,u), dot(va-vb,v) );
  vec2 n = vec2( dot(vc-vb,u), dot(vc-vb,v) );
  vec3 q = vec3( dot( p-vb,u), dot( p-vb,v), dot(p-vb,w) );
  //----  
  float mn = det(m,n);
  float mq = det(m,q.xy);
  float nq = det(n,q.xy);
  //----  
  vec2  g = (nq+mq+mn)*n + (nq+mq-mn)*m;
  float f = (nq-mq+mn)*(nq-mq+mn) + 4.0*mq*nq;
  vec2  z = 0.5*f*vec2(-g.y,g.x)/dot(g,g);
//float t = clamp(0.5+0.5*(det(z,m+n)+mq+nq)/mn, 0.0 ,1.0 );
  float t = clamp(0.5+0.5*(det(z-q.xy,m+n))/mn, 0.0 ,1.0 );
  vec2 cp = m*(1.0-t)*(1.0-t) + n*t*t - q.xy;
  //----  
  float d2 = dot(cp,cp);
  return vec4(sqrt(d2+q.z*q.z), t, q.z, -sign(f)*sqrt(d2) );
}
#else
float det( vec3 a, vec3 b, in vec3 v ) { return dot(v,cross(a,b)); }

// my adaptation to 3d of http://research.microsoft.com/en-us/um/people/hoppe/ravg.pdf
// { dist, t, y (above the plane of the curve, x (away from curve in the plane of the curve))
vec4 sdBezier( vec3 p, vec3 b0, vec3 b1, vec3 b2 )
{
    b0 -= p;
    b1 -= p;
    b2 -= p;
    
    vec3  d21 = b2-b1;
    vec3  d10 = b1-b0;
    vec3  d20 = (b2-b0)*0.5;

    vec3  n = normalize(cross(d10,d21));

    float a = det(b0,b2,n);
    float b = det(b1,b0,n);
    float d = det(b2,b1,n);
    vec3  g = b*d21 + d*d10 + a*d20;
	float f = a*a*0.25-b*d;

    vec3  z = cross(b0,n) + f*g/dot(g,g);
    float t = clamp( dot(z,d10-d20)/(a+b+d), 0.0 ,1.0 );
    vec3 q = mix(mix(b0,b1,t), mix(b1,b2,t),t);
    
    float k = dot(q,n);
    return vec4(length(q),t,-k,-sign(f)*length(q-n*k));
}
#endif

// https://iquilezles.org/articles/distfunctions
vec2 sdSegment(vec3 p, vec3 a, vec3 b)
{
    vec3 pa = p-a, ba = b-a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
	return vec2( length( pa - ba*h ), h );
}

// https://iquilezles.org/articles/distfunctions
vec2 sdSegmentOri(vec2 p, vec2 b)
{
	float h = clamp( dot(p,b)/dot(b,b), 0.0, 1.0 );
	return vec2( length( p - b*h ), h );
}

// https://iquilezles.org/articles/distfunctions
float sdFakeRoundCone(vec3 p, float b, float r1, float r2)
{
    float h = clamp( p.y/b, 0.0, 1.0 );
    p.y -= b*h;
	return length(p) - mix(r1,r2,h);
}

// https://iquilezles.org/articles/distfunctions
float sdCone( in vec3 p, in vec2 c )
{
  vec2 q = vec2( length(p.xz), p.y );

  vec2 a = q - c*clamp( (q.x*c.x+q.y*c.y)/dot(c,c), 0.0, 1.0 );
  vec2 b = q - c*vec2( clamp( q.x/c.x, 0.0, 1.0 ), 1.0 );
  
  float s = -sign( c.y );
  vec2 d = min( vec2( dot( a, a ), s*(q.x*c.y-q.y*c.x) ),
			    vec2( dot( b, b ), s*(q.y-c.y)  ));
  return -sqrt(d.x)*sign(d.y);
}

// https://iquilezles.org/articles/distfunctions
float sdRhombus(vec3 p, float la, float lb, float h, float ra)
{
    p = abs(p);
    vec2 b = vec2(la,lb);
    float f = clamp( (ndot(b,b-2.0*p.xz))/dot(b,b), -1.0, 1.0 );
	vec2 q = vec2(length(p.xz-0.5*b*vec2(1.0-f,1.0+f))*sign(p.x*b.y+p.z*b.x-b.x*b.y)-ra, p.y-h);
    return min(max(q.x,q.y),0.0) + length(max(q,0.0));
}

// https://iquilezles.org/articles/distfunctions
vec4 opElongate( in vec3 p, in vec3 h )
{
    vec3 q = abs(p)-h;
    return vec4( max(q,0.0), min(max(q.x,max(q.y,q.z)),0.0) );
}

//-----------------------------------------------

// ray-infinite-cylinder intersection
vec2 iCylinderY( in vec3 ro, in vec3 rd, in float rad )
{
	vec3 oc = ro;
    float a = dot( rd.xz, rd.xz );
	float b = dot( oc.xz, rd.xz );
	float c = dot( oc.xz, oc.xz ) - rad*rad;
	float h = b*b - a*c;
	if( h<0.0 ) return vec2(-1.0);
    h = sqrt(h);
	return vec2(-b-h,-b+h)/a;
}

// Clip a ray interval to the shared full-character bounding cylinder.
bool clipCharacterBounds( in vec3 ro, in vec3 rd, inout float t, inout float tmax )
{
    // Conservative world-space bounds for the shoes, body and animated hair.
    // Intersect the radial cylinder and its Y slab with the supplied ray interval.
    const float radius = 2.2;
    const vec2 height = vec2(-6.6,1.6);

    float a = dot(rd.xz,rd.xz);
    float b = dot(ro.xz,rd.xz);
    float c = dot(ro.xz,ro.xz)-radius*radius;
    if( a>0.0 )
    {
        float discriminant = b*b-a*c;
        if( discriminant<0.0 ) return false;
        float root = sqrt(discriminant);
        t = max(t,(-b-root)/a);
        tmax = min(tmax,(-b+root)/a);
    }
    else if( c>0.0 ) return false; // Axis-parallel ray outside the radius.

    if( rd.y!=0.0 )
    {
        vec2 caps = (height-ro.y)/rd.y;
        t = max(t,min(caps.x,caps.y));
        tmax = min(tmax,max(caps.x,caps.y));
    }
    else if( ro.y<height.x || ro.y>height.y ) return false;

    // Covers misses, intersections behind the ray, and entry beyond the requested range.
    if( t>=tmax ) return false;

    return true;
}

// ray-infinite-cone intersection
vec2 iConeY(in vec3 ro, in vec3 rd, in float k )
{
	float a = dot(rd.xz,rd.xz) - k*rd.y*rd.y;
    float b = dot(ro.xz,rd.xz) - k*ro.y*rd.y;
    float c = dot(ro.xz,ro.xz) - k*ro.y*ro.y; 
        
    float h = b*b-a*c;
    if( h<0.0 ) return vec2(-1.0);
    h = sqrt(h);
    return vec2(-b-h,-b+h)/a;
}

//-----------------------------------------------

float linearstep(float a, float b, in float x )
{
    return clamp( (x-a)/(b-a), 0.0, 1.0 );
}

vec2 rot( in vec2 p, in float an )
{
    float cc = cos(an);
    float ss = sin(an);
    return mat2(cc,-ss,ss,cc)*p;
}

float expSustainedImpulse( float t, float f, float k )
{
    return smoothstep(0.0,f,t)*1.1 - 0.1*exp2(-k*max(t-f,0.0));
}

//-----------------------------------------------

vec3 hash3( uint n ) 
{
    // integer hash copied from Hugo Elias
	n = (n << 13U) ^ n;
    n = n * (n * n * 15731U + 789221U) + 1376312589U;
    uvec3 k = n * uvec3(n,n*16807U,n*48271U);
    return vec3( k & uvec3(0x7fffffffU))/float(0x7fffffff);
}

//---------------------------------------

float noise1( sampler2D tex, in vec3 x )
{
    // 32^3 value-noise volume stored as a 2D atlas in texture0.png (33 x 1056):
    // 32 slices of 33 rows x 33 cols (32 real + one duplicated wrap row/col), so
    // hardware linear filtering wraps seamlessly in x/y and we blend z manually.
    vec3 p = x - 32.0*floor(x/32.0); // wrap lattice coord to [0,32)
    vec3 i = floor(p);
    vec3 f = p - i;
    float z1 = mod(i.z + 1.0, 32.0);
    float u  = (i.x + 0.5 + f.x)*(1.0/33.0);
    float v0 = (i.z*33.0 + i.y + 0.5 + f.y)*(1.0/1056.0);
    float v1 = (z1*33.0 + i.y + 0.5 + f.y)*(1.0/1056.0);
    float n0 = textureLod(tex, vec2(u, v0), 0.0).x;
    float n1 = textureLod(tex, vec2(u, v1), 0.0).x;
    return mix(n0, n1, f.z);
}
float noise1( sampler2D tex, in vec2 x )
{
    return textureLod(tex,(x+0.5)/64.0,0.0).x;
}
float noise1f( sampler2D tex, in vec2 x )
{
    return texture(tex,(x+0.5)/64.0).x;
}
float fbm1( sampler2D tex, in vec3 x )
{
    float f = 0.0;
    f += 0.5000*noise1(tex,x); x*=2.01;
    f += 0.2500*noise1(tex,x); x*=2.01;
    f += 0.1250*noise1(tex,x); x*=2.01;
    f += 0.0625*noise1(tex,x);
    f = 2.0*f-0.9375;
    return f;
}

float fbm1( sampler2D tex, in vec2 x )
{
    float f = 0.0;
    f += 0.5000*noise1(tex,x); x*=2.01;
    f += 0.2500*noise1(tex,x); x*=2.01;
    f += 0.1250*noise1(tex,x); x*=2.01;
    f += 0.0625*noise1(tex,x);
    f = 2.0*f-0.9375;
    return f;
}
float fbm1f( sampler2D tex, in vec2 x )
{
    float f = 0.0;
    f += 0.5000*noise1f(tex,x); x*=2.01;
    f += 0.2500*noise1f(tex,x); x*=2.01;
    f += 0.1250*noise1f(tex,x); x*=2.01;
    f += 0.0625*noise1f(tex,x);
    f = 2.0*f-0.9375;
    return f;
}
float bnoise( in float x )
{
    float i = floor(x);
    float f = fract(x);
    float s = sign(fract(x/2.0)-0.5);
    float k = 0.5+0.5*sin(i);
    return s*f*(f-1.0)*((16.0*k-4.0)*f*(f-1.0)-1.0);
}
vec3 fbm13( in float x, in float g )
{    
    vec3 n = vec3(0.0);
    float s = 1.0;
    for( int i=0; i<6; i++ )
    {
        n += s*vec3(bnoise(x),bnoise(x+13.314),bnoise(x+31.7211));
        s *= g;
        x *= 2.01;
        x += 0.131;
    }
    return n;
}

//--------------------------------------------------
//const float X1 = 1.6180339887498948; const float H1 = float( 1.0/X1 );
//const float X2 = 1.3247179572447460; const vec2  H2 = vec2(  1.0/X2, 1.0/(X2*X2) );
//const float X3 = 1.2207440846057595; const vec3  H3 = vec3(  1.0/X3, 1.0/(X3*X3), 1.0/(X3*X3*X3) );
  const float X4 = 1.1673039782614187; const vec4  H4 = vec4(  1.0/X4, 1.0/(X4*X4), 1.0/(X4*X4*X4), 1.0/(X4*X4*X4*X4) );

//--------------------------------------
mat3 calcCamera( in float time, out vec3 oRo, out float oFl )
{
    vec3 ta = vec3( 0.0, -0.3, 0.0 );
    vec3 ro = vec3( -0.5563, -0.2, 2.7442 );
    float fl = 1.7;
#if 0
    vec3 fb = fbm13( 0.2*time, 0.5 );
    ta += 0.025*fb;
    float cr = -0.01 + 0.006*fb.z;
#else
    vec3 fb1 = fbm13( 0.15*time, 0.50 );
    ro.xyz += 0.010*fb1.xyz;
    vec3 fb2 = fbm13( 0.33*time, 0.65 );
    fb2 = fb2*fb2*sign(fb2);
    ta.xy += 0.005*fb2.xy;
    float cr = -0.01 + 0.002*fb2.z;
#endif
    
    // camera matrix
    vec3 ww = normalize( ta - ro );
    vec3 uu = normalize( cross(ww,vec3(sin(cr),cos(cr),0.0) ) );
    vec3 vv =          ( cross(uu,ww));
    
    oRo = ro;
    oFl = fl;

    return mat3(uu,vv,ww);
}

#define ZERO min(iFrame,0)
#define ZEROU min(uint(iFrame),0u)

// Copyright Inigo Quilez, 2020 - https://iquilezles.org/
// I am the sole copyright owner of this Work. You cannot
// host, display, distribute or share this Work neither as
// is or altered, in any form including physical and
// digital. You cannot use this Work in any commercial or
// non-commercial product, website or project. You cannot
// sell this Work and you cannot mint an NFTs of it. You
// cannot use this Work to train AI models. I share this
// Work for educational purposes, you can link to it as
// an URL, proper attribution and unmodified screenshot,
// as part of your educational material. If these
// conditions are too restrictive please contact me.


// Source code of the mathematical painting "Selfie Girl".
// Making-of video on Youtube:
//
// Tutorial on Youtube:  https://www.youtube.com/watch?v=8--5LwHRhjk
// Tutorial on Bilibili: https://www.bilibili.com/video/BV1Hu4y1y7U1

// The image is a single formula, but I had to split it
// down into 3 passes here so it could be shared without
// breaking the WebGL implementation of the web browsers
// (which is what Shadertoy uses to run the code below
// that implements the formula).

// Suit study: the girl wears a patterned blazer in a 36-second camera orbit.
// The complete outfit and a world-space background render in this Image pass.
// Spatial supersampling keeps animated facial details sharp without TAA.

// Shared quality settings must precede both intersect and mainImage.
#define INTERACTIVE 1  // Set to 1 for fast preview; 0 preserves final quality.
#if INTERACTIVE
    #define AA 1
    const int RAYMARCH_STEPS = 160;
    const float RAYMARCH_EPSILON = 0.001;
#else
    // Four spatial samples per pixel, all at the same animation time.
    #define AA 2
    const int RAYMARCH_STEPS = 320;
    const float RAYMARCH_EPSILON = 0.00035;
#endif

const float SKIN_DETAIL = 0.00022;
const float HAIR_DETAIL = 0.0012;
const float PORTRAIT_EXPOSURE = 1.12;
const float ORBIT_SECONDS = 36.0; // One complete camera revolution.


// Moves the head and hair while the tailored jacket stays on the torso.
// This could be done
// more efficiently (with a single matrix or quaternion),
// but this code was optimized for editing, not for runtime
vec3 moveHead( in vec3 pos, in vec3 an, in float amount)
{
    pos.y -= -1.0;
    pos.xz = rot(pos.xz,amount*an.x);
    pos.xy = rot(pos.xy,amount*an.y);
    pos.yz = rot(pos.yz,amount*an.z);
    pos.y += -1.0;
    return pos;
}

// the animation state
vec3 animData; // { blink, nose follow up, mouth } 
vec3 animHead; // { head rotation angles }

// Animates the eye central position (not the actual random
// darts). It's carefuly synched with the head motion, to
// make the eyes anticipate the head turn (without this
// anticipation, the eyes and the head are disconnected and
// it all looks like a zombie/animatronic)
//
float animEye( in float time )
{
    const float w = 6.1;
    float t = mod(time-0.31,w*1.0);
    
    float q = fract((time-0.31)/(2.0*w));
    float s = (q > 0.5) ? 1.0 : 0.0;
    return (t<0.15)?1.0-s:s;
}

// Animates the head turn. This is my first time animating
// and I am aware I'm in uncanny/animatronic land. But I
// have to start somwhere!
//
float animTurn( in float time )
{
    const float w = 6.1;
    float t = mod(time,w*2.0);
    
    vec3 p = (t<w) ? vec3(0.0,0.0,1.0) : vec3(w,1.0,-1.0);
    return p.y + p.z*expSustainedImpulse(t-p.x,1.0,10.0);
}

// Animates the eye blinks. Blinks are motivated by head
// turns (again, in an attempt tp avoid animatronic and
// zoombie feel), but also there are random blinks. This
// same funcion is called with some delay and extra
// smmoothness to get the blink of the eyes be followed by
// the face muscles around the face.
//
float animBlink( in float time, in float smo )
{
    // head-turn motivated blink
    const float w = 6.1;
    float t = mod(time-0.31,w*1.0);
    float blink = smoothstep(0.0,0.1,t) - smoothstep(0.18,0.4,t);

    // regular blink
    float tt = mod(1.0+time,3.0);
    blink = max(blink,smoothstep(0.0,0.07+0.07*smo,tt)-smoothstep(0.1+0.04*smo,0.35+0.3*smo,tt));
    
    // keep that eye alive always
    float blinkBase = 0.04*(0.5+0.5*sin(time));
    blink = mix( blinkBase, 1.0, blink );

    // base pose is a bit down
    float down = 0.15;
    return down+(1.0-down)*blink;
}

mat3 portraitCamera(in float seconds,out vec3 ro)
{
    float angle = -0.10+6.28318530718*mod(seconds,ORBIT_SECONDS)/ORBIT_SECONDS;
    ro = vec3(7.9*sin(angle),-0.60,7.9*cos(angle));
    vec3 target = vec3(0.0,-1.75,0.0);
    vec3 forward = normalize(target-ro);
    vec3 right = normalize(cross(forward,vec3(0.0,1.0,0.0)));
    return mat3(right,cross(right,forward),forward);
}
