// Standalone blazer SDF preview for Shader Studio.
// All helper names are local to this file, so it can be added as an Image pass
// without modifying the existing Selfie Girl shader or its Common pass.

#define BLAZER_MAX_STEPS 100
#define BLAZER_SURF_DIST 0.001
#define BLAZER_MAX_DIST 100.0

mat2 blazerRot( float a )
{
    float c = cos(a), s = sin(a);
    return mat2(c,-s,s,c);
}

float blazerSmoothUnion( float a, float b, float k )
{
    float h = clamp(0.5 + 0.5*(b-a)/k,0.0,1.0);
    return mix(b,a,h) - k*h*(1.0-h);
}

float blazerRoundBox( vec3 p, vec3 b, float r )
{
    vec3 q = abs(p)-b;
    return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;
}

float blazerCapsule( vec3 p, vec3 a, vec3 b, float r )
{
    vec3 pa = p-a, ba = b-a;
    float h = clamp(dot(pa,ba)/dot(ba,ba),0.0,1.0);
    return length(pa-ba*h)-r;
}

float blazerTaperedCapsule( vec3 p, vec3 a, vec3 b, float r0, float r1 )
{
    vec3 pa = p-a, ba = b-a;
    float h = dot(pa,ba)/dot(ba,ba);
    if( h <= 0.0 ) return length(pa)-r0;
    if( h >= 1.0 ) return length(p-b)-r1;
    return length(pa-ba*h)-mix(r0,r1,h);
}

float blazerEllipsoid( vec3 p, vec3 r )
{
    float k0 = length(p/r);
    float k1 = length(p/(r*r));
    return k0*(k0-1.0)/k1;
}

float blazerTorus( vec3 p, vec2 t )
{
    return length(vec2(length(p.xz)-t.x,p.y))-t.y;
}

float blazerCross( vec2 a, vec2 b )
{
    return a.x*b.y-a.y*b.x;
}

float blazerSegmentDistance( vec2 p, vec2 a, vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    return length(pa-ba*clamp(dot(pa,ba)/dot(ba,ba),0.0,1.0));
}

float blazerTrianglePrism( vec3 p, vec2 a, vec2 b, vec2 c, float halfDepth )
{
    float winding = sign(blazerCross(b-a,c-a));
    float inside = min(blazerCross(b-a,p.xy-a),
                       min(blazerCross(c-b,p.xy-b),blazerCross(a-c,p.xy-c)))*winding;
    float edge = min(blazerSegmentDistance(p.xy,a,b),
                     min(blazerSegmentDistance(p.xy,b,c),blazerSegmentDistance(p.xy,c,a)));
    float triangle = mix(edge,-edge,step(0.0,inside));
    vec2 d = vec2(triangle,abs(p.z)-halfDepth);
    return min(max(d.x,d.y),0.0)+length(max(d,0.0));
}

float blazerHash( vec3 p )
{
    return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);
}

float blazerNoise( vec3 p )
{
    vec3 i = floor(p), f = fract(p);
    f = f*f*(3.0-2.0*f);
    return mix(mix(mix(blazerHash(i+vec3(0,0,0)),blazerHash(i+vec3(1,0,0)),f.x),
                   mix(blazerHash(i+vec3(0,1,0)),blazerHash(i+vec3(1,1,0)),f.x),f.y),
               mix(mix(blazerHash(i+vec3(0,0,1)),blazerHash(i+vec3(1,0,1)),f.x),
                   mix(blazerHash(i+vec3(0,1,1)),blazerHash(i+vec3(1,1,1)),f.x),f.y),f.z);
}

float blazerFbm( vec3 p )
{
    return 0.57*blazerNoise(p) + 0.29*blazerNoise(p*2.03) + 0.14*blazerNoise(p*4.07);
}

// Same tiled 32^3 noise atlas layout used by the hoodie material in
// selfie.glsl. Shader Studio binds texture0.png to iChannel0 in the preview.
float blazerNoiseAtlas( sampler2D tex, vec3 x )
{
    vec3 p = x - 32.0*floor(x/32.0);
    vec3 i = floor(p);
    vec3 f = p-i;
    float z1 = mod(i.z+1.0,32.0);
    float u = (i.x+0.5+f.x)/33.0;
    float v0 = (i.z*33.0+i.y+0.5+f.y)/1056.0;
    float v1 = (z1*33.0+i.y+0.5+f.y)/1056.0;
    return mix(textureLod(tex,vec2(u,v0),0.0).x,
               textureLod(tex,vec2(u,v1),0.0).x,f.z);
}

// Front-facing single-breasted blazer: broad shoulders, long sleeves, lapels,
// collar, pockets, buttons, and a rounded split hem.
float sdJacket( in vec3 p )
{
    vec3 q = p;

    // A shaped torso replaces the previous uniform rounded box. The chest is
    // broad, the waist draws in, and the lower quarters regain a little width.
    float chestMask = smoothstep(-0.20,0.92,q.y);
    float hemMask = 1.0-smoothstep(-1.02,-0.62,q.y);
    float torsoWidth = mix(0.50,0.62,chestMask);
    torsoWidth = mix(torsoWidth,0.56,hemMask);
    vec3 torso = q-vec3(0.0,-0.03,0.015+0.040*chestMask);
    torso.x /= torsoWidth;
    float jacket = blazerRoundBox(torso,vec3(1.0,1.05,0.285),0.105);

    // Shoulder pads and sleeves give the straight, tailored outline in the reference.
    float shoulderL = blazerCapsule(q,vec3(-0.57,0.83,0.0),vec3(-0.77,0.69,0.0),0.17);
    float shoulderR = blazerCapsule(q,vec3( 0.57,0.83,0.0),vec3( 0.77,0.69,0.0),0.17);
    float sleeveL = blazerTaperedCapsule(q,vec3(-0.77,0.63,0.0),vec3(-0.84,-0.85,0.02),0.155,0.125);
    float sleeveR = blazerTaperedCapsule(q,vec3( 0.77,0.63,0.0),vec3( 0.84,-0.85,0.02),0.155,0.125);
    jacket = blazerSmoothUnion(jacket,shoulderL,0.045);
    jacket = blazerSmoothUnion(jacket,shoulderR,0.045);
    jacket = blazerSmoothUnion(jacket,sleeveL,0.035);
    jacket = blazerSmoothUnion(jacket,sleeveR,0.035);

    // The open front is a deep V, leaving a light lining visible behind the lapels.
    float opening = max(abs(q.x)-0.055-0.32*smoothstep(-0.05,0.76,q.y),abs(q.z-0.30)-0.16);
    jacket = max(jacket,-opening);

    // Clear a real neck hole before adding the folded collar/lapels.
    float neckCut = blazerEllipsoid(q-vec3(0.0,1.10,0.16),vec3(0.30,0.28,0.34));
    jacket = max(jacket,-neckCut);

    // Wide notched lapels, folded collar, and a centre seam.
    float lapelL = blazerTrianglePrism(q-vec3(0.0,0.0,0.408),
                                       vec2(-0.16,0.94),vec2(-0.52,0.73),vec2(-0.06,-0.10),0.014);
    float lapelR = blazerTrianglePrism(q-vec3(0.0,0.0,0.408),
                                       vec2(0.16,0.94),vec2(0.06,-0.10),vec2(0.52,0.73),0.014);
    jacket = blazerSmoothUnion(jacket,lapelL,0.010);
    jacket = blazerSmoothUnion(jacket,lapelR,0.010);

    // Raised pocket flaps, chest welt, buttons, and sleeve cuffs.
    for( int side=-1; side<=1; side+=2 )
    {
        float sx = float(side);
        vec3 flap = q-vec3(sx*0.35,-0.39,0.405);
        jacket = blazerSmoothUnion(jacket,blazerRoundBox(flap,vec3(0.18,0.070,0.009),0.012),0.006);
        vec3 welt = q-vec3(sx*0.35,-0.48,0.408);
        jacket = blazerSmoothUnion(jacket,blazerRoundBox(welt,vec3(0.17,0.010,0.010),0.006),0.006);
    }
    jacket = blazerSmoothUnion(jacket,length(q-vec3(0.08,0.05,0.394))-0.024,0.006);
    jacket = blazerSmoothUnion(jacket,length(q-vec3(0.08,-0.32,0.394))-0.022,0.006);

    // The open front exposes a soft lining instead of the empty background.
    float lining = blazerTrianglePrism(q-vec3(0.0,0.0,0.320),
                                       vec2(-0.15,0.82),vec2(0.0,-0.98),vec2(0.15,0.82),0.018);
    jacket = min(jacket,lining);

    // Keep the fabric variation shallow so it cannot change the silhouette.
    float cloth = blazerFbm(q*vec3(16.0,18.0,20.0));
    jacket += 0.0015*cloth*smoothstep(0.006,0.0,abs(jacket));
    return jacket;
}

float blazerScene( in vec3 p )
{
    return sdJacket(p);
}

float rayMarchBlazer( in vec3 ro, in vec3 rd )
{
    float distanceTravelled = 0.0;
    for( int step=0; step<BLAZER_MAX_STEPS; step++ )
    {
        float distanceToScene = blazerScene(ro + rd*distanceTravelled);
        distanceTravelled += distanceToScene;
        if( distanceToScene<BLAZER_SURF_DIST || distanceTravelled>BLAZER_MAX_DIST ) break;
    }
    return distanceTravelled;
}

vec3 blazerNormal( in vec3 p )
{
    const float e = 0.0015;
    return normalize(vec3(
        blazerScene(p+vec3(e,0.0,0.0))-blazerScene(p-vec3(e,0.0,0.0)),
        blazerScene(p+vec3(0.0,e,0.0))-blazerScene(p-vec3(0.0,e,0.0)),
        blazerScene(p+vec3(0.0,0.0,e))-blazerScene(p-vec3(0.0,0.0,e))));
}

float blazerAmbientOcclusion( in vec3 p, in vec3 n )
{
    float occlusion = 0.0;
    for( int i=1; i<=4; i++ )
    {
        float h = 0.035*float(i);
        occlusion += max(0.0,h-blazerScene(p+n*h));
    }
    return clamp(1.0-2.3*occlusion,0.0,1.0);
}

float blazerSoftShadow( in vec3 ro, in vec3 rd )
{
    float result = 1.0;
    float t = 0.015;
    for( int i=0; i<48; i++ )
    {
        float h = blazerScene(ro + rd*t);
        result = min(result,8.0*h/t);
        t += clamp(h,0.008,0.12);
        if( result<0.01 || t>5.0 ) break;
    }
    return clamp(result,0.0,1.0);
}

float blazerLapelDistance( in vec3 p )
{
    float left = blazerTrianglePrism(p-vec3(0.0,0.0,0.408),
                                     vec2(-0.16,0.94),vec2(-0.52,0.73),vec2(-0.06,-0.10),0.014);
    float right = blazerTrianglePrism(p-vec3(0.0,0.0,0.408),
                                      vec2(0.16,0.94),vec2(0.06,-0.10),vec2(0.52,0.73),0.014);
    return min(abs(left),abs(right));
}

float blazerLiningDistance( in vec3 p )
{
    return abs(blazerTrianglePrism(p-vec3(0.0,0.0,0.320),
                                   vec2(-0.15,0.82),vec2(0.0,-0.98),vec2(0.15,0.82),0.018));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (-iResolution.xy+2.0*fragCoord)/iResolution.y;

    // Selfie Girl uses a compact look-at camera with a slight side offset.
    // This keeps the product front-facing while giving its folds some depth.
    vec3 ro = vec3(-0.18,0.04,4.65);
    vec3 ta = vec3(0.0,-0.05,0.0);
    vec3 ww = normalize(ta-ro);
    vec3 uu = normalize(cross(ww,vec3(0.0,1.0,0.0)));
    vec3 vv = cross(uu,ww);
    vec3 rd = normalize(uv.x*0.92*uu + uv.y*0.92*vv + 1.90*ww);
    float rayDistance = rayMarchBlazer(ro,rd);
    vec3 color = mix(vec3(0.89,0.87,0.83),vec3(0.98,0.97,0.94),0.5+0.5*uv.y);

    if( rayDistance<BLAZER_MAX_DIST )
    {
        vec3 p = ro + rd*rayDistance;
        vec3 normal = blazerNormal(p);
        vec3 lightDirection = normalize(vec3(0.57,0.46,0.68));
        vec3 halfVector = normalize(lightDirection-rd);
        float diffuse = clamp(dot(normal,lightDirection),0.0,1.0);
        float shadow = blazerSoftShadow(p+normal*0.004,lightDirection);
        float ao = blazerAmbientOcclusion(p,normal);
        float fresnel = clamp(1.0+dot(normal,rd),0.0,1.0);
        float specular = 0.34*pow(max(dot(normal,halfVector),0.0),12.0)*diffuse*shadow;
        float lapelMask = smoothstep(0.025,0.0,blazerLapelDistance(p));
        float liningMask = smoothstep(0.025,0.0,blazerLiningDistance(p));
        // The hoodie lookup is deliberately compressed here: on a broad blazer
        // panel it reads as a fine heathered weave instead of salt-and-pepper noise.
        float knit = 0.5*(blazerNoiseAtlas(iChannel0,p*112.0-0.5) +
                          blazerNoiseAtlas(iChannel0,p*112.0+vec3(11.7,4.1,19.3)));
        vec3 fabric = vec3(0.42,0.405,0.380)*(0.88+0.24*knit);
        fabric = mix(fabric,fabric*0.82,0.35*lapelMask);
        fabric = mix(fabric,vec3(0.58)*mix(0.85,1.05,knit),0.72*liningMask);

        float ambient = ao*(0.55+0.45*normal.y);
        float bounced = clamp(0.3-0.7*normal.x,0.0,1.0);
        vec3 lighting = vec3(0.65,1.05,2.0)*ambient*1.15;
        lighting += 0.92*vec3(1.60,1.40,1.20)*(0.35+0.65*diffuse)*shadow;
        lighting += 0.22*vec3(4.0,2.0,1.0)*bounced*ao*fabric;
        color = lighting*fabric + specular + 0.10*fresnel*fresnel*fresnel*ao;
    }

    // Match the display response used by the Selfie Girl Image pass.
    color = pow(max(color,0.0),vec3(0.4545));
    color = 3.8*color/(3.0+dot(color,vec3(0.333)));
    color = color*vec3(1.02,1.00,0.99)+vec3(0.0,0.0,0.045);

    fragColor = vec4(color,1.0);
}
