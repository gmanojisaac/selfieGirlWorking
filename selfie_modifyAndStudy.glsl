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

// 2 = four spatial samples per pixel. Use 3 for a nine-sample still export.
// Keep every sample at the same time so blinking does not soften the face.
#define AA 2

const float SKIN_DETAIL = 0.00022;
const float HAIR_DETAIL = 0.0012;
const float PORTRAIT_EXPOSURE = 1.12;
const float ORBIT_SECONDS = 36.0; // One complete camera revolution.


// This SDF is really 6 braids at once (through domain
// repetition) with three strands each (brute forced)
vec4 sdHair( vec3 p, vec3 pa, vec3 pb, vec3 pc, float an, out vec2 occ_id) 
{
    vec4 b = sdBezier(p, pa,pb,pc );
    vec2 q = rot(b.zw,an);
      
    vec2 id2 = round(q/0.1);
    id2 = clamp(id2,vec2(0),vec2(2,1));
    q -= 0.1*id2;

    float id = 11.0*id2.x + id2.y*13.0;

    q += smoothstep(0.5,0.8,b.y)*vec2(0.4,1.5)*
         0.02*cos( 23.0*b.y + id*vec2(13,17));

    occ_id.x = clamp(length(q)*8.0-0.2,0.0,1.0);
    vec4 res = vec4(99,q,b.y);
    for( int i=0; i<3; i++ )
    {
        vec2 tmp = q + 0.01*cos( id + 180.0*b.y + vec2(2*i,6-2*i));
        float lt = length(tmp)-0.02;
        if( lt<res.x )
        { 
            occ_id.y = id+float(i); 
            res.x = lt; 
            res.yz = tmp;
        }
    }
    return res;
}

// Eleven curved back braids follow the skull before falling to the shoulders.
vec4 sdRearBraids(vec3 pos,out vec2 occ_id)
{
    float id = clamp(round(pos.x/0.13),-5.0,5.0);
    float edge = abs(id)/5.0;
    pos.x -= id*0.13;
    vec4 b = sdBezier(pos,vec3(0.0,0.85-0.34*edge*edge,-0.25),
                         vec3(0.0,0.44-0.12*edge,-1.32+0.42*edge*edge),
                         vec3(0.025*sin(id),-1.46+0.07*sin(id*2.1),-0.70+0.22*edge));
    vec2 q = b.zw;
    vec4 result = vec4(99.0,0.0,0.0,b.y);
    occ_id = vec2(clamp(length(q)*8.0,0.0,1.0),180.0+id*3.0);
    for(int i=0;i<3;i++)
    {
        vec2 strand = q+0.025*cos(128.0*b.y+float(i)*2.094395+id+vec2(0.0,1.570796));
        float d = length(strand)-0.021;
        if(d<result.x) { result = vec4(d,strand,b.y); occ_id.y = 180.0+id*3.0+float(i); }
    }
    return result;
}

// Tailored blazer: real front/back volume, folded lapels, pockets and cuffs.
// Material IDs: 1 skin, 3 brocade, 6 blouse, 7 buttons, 8 trousers, 9 shoes.
float suitBox(vec3 p,vec3 size,float radius)
{
    vec3 d = abs(p)-size;
    return length(max(d,0.0))+min(max(d.x,max(d.y,d.z)),0.0)-radius;
}

float suitCross(vec2 a,vec2 b) { return a.x*b.y-a.y*b.x; }
float suitEdge(vec2 p,vec2 a,vec2 b)
{
    vec2 v = b-a;
    return length(p-a-v*clamp(dot(p-a,v)/dot(v,v),0.0,1.0));
}
float suitTriangle(vec3 p,vec2 a,vec2 b,vec2 c,float thickness)
{
    float winding = sign(suitCross(b-a,c-a));
    float inside = min(winding*suitCross(b-a,p.xy-a),
                  min(winding*suitCross(c-b,p.xy-b),winding*suitCross(a-c,p.xy-c)));
    float edge = min(suitEdge(p.xy,a,b),min(suitEdge(p.xy,b,c),suitEdge(p.xy,c,a)));
    vec2 d = vec2(inside>=0.0 ? -edge : edge,abs(p.z)-thickness);
    return min(max(d.x,d.y),0.0)+length(max(d,0.0));
}
float suitButton(vec3 p,float radius)
{
    vec2 d = vec2(length(p.xy)-radius,abs(p.z)-0.009);
    float button = min(max(d.x,d.y),0.0)+length(max(d,0.0))-0.003;
    vec2 holes = abs(p.xy)-vec2(radius*0.27);
    return max(button,-(length(holes)-radius*0.10));
}
float suitHand(vec3 p)
{
    p.x = abs(p.x);
    float d = sdEllipsoid(p-vec3(1.25,-3.92,0.10),vec3(0.13,0.23,0.085));
    d = smin(d,sdSegment(p,vec3(1.14,-3.79,0.12),vec3(1.09,-3.98,0.16)).x-0.047,0.035);
    for(int i=0;i<4;i++)
    {
        float x = 1.16+0.057*float(i);
        float bottom = -4.18+0.025*abs(float(i)-1.5);
        d = smin(d,sdSegment(p,vec3(x,-3.95,0.12),vec3(x,bottom,0.14)).x-0.029,0.018);
    }
    return d;
}

// An interwoven floral tile, evaluated on the cloth rather than projected photos.
float suitBrocade(vec2 uv)
{
    vec2 cell = uv*13.0;
    cell.x += 0.5*mod(floor(cell.y),2.0);
    vec2 p = fract(cell)-0.5;
    float angle = atan(p.y,p.x);
    float radius = length(p);
    float petal = 0.265+0.075*cos(4.0*angle);
    float flower = 1.0-smoothstep(0.012,0.036,abs(radius-petal));
    float inner = 1.0-smoothstep(0.01,0.028,abs(radius-petal*0.64));
    float vine = 1.0-smoothstep(0.012,0.035,abs(p.x-0.15*sin(p.y*9.0)));
    return clamp(0.6*flower+0.3*inner+0.18*vine,0.0,1.0);
}

vec4 mapSuit(vec3 pos)
{
    vec3 q = pos-vec3(0.0,-2.6,0.0);
    float chest = smoothstep(-0.15,0.9,q.y);
    float hem = 1.0-smoothstep(-1.1,-0.55,q.y);
    float width = 0.69+0.17*chest+0.10*hem;
    vec3 body = q;
    body.z += 0.04*chest;
    body.z += 0.008*sin(q.y*7.0+q.x*5.0)*smoothstep(0.5,0.9,abs(q.x));
    float jacket = suitBox(body,vec3(width-0.14,1.13,0.26+0.035*chest),0.14);

    // Fitted V opening and a neck opening continue through the top surface.
    float openingWidth = 0.048+0.30*clamp((q.y+0.28)/1.40,0.0,1.0);
    float opening = max(abs(q.x)-openingWidth,max(-q.y-0.28,0.06-q.z));
    jacket = max(jacket,-opening);
    float neck = sdEllipsoid(q-vec3(0.0,1.29,0.06),vec3(0.36,0.34,0.40));
    jacket = max(jacket,-neck);
    // Rounded front quarters and a small opening below the lower button.
    float cut = max(abs(q.x)-(0.012+0.22*smoothstep(0.75,1.30,-q.y)),max(q.y+0.71,0.02-q.z));
    jacket = max(jacket,-cut);

    vec3 side = vec3(abs(q.x),q.yz);
    vec2 upper = sdSegment(side,vec3(0.83,0.93,0.0),vec3(1.12,0.01,0.0));
    vec2 lower = sdSegment(side,vec3(1.12,0.01,0.0),vec3(1.24,-1.04,0.04));
    float upperSleeve = upper.x-mix(0.25,0.20,upper.y);
    float lowerSleeve = lower.x-mix(0.20,0.155,lower.y);
    float sleeve = smin(upperSleeve,lowerSleeve,0.10);
    // Broad elbow folds, with a flat cuff at the wrist.
    sleeve += 0.008*sin(34.0*side.y+9.0*side.z)*exp(-side.y*side.y*20.0);
    sleeve = max(sleeve,-1.17-side.y);
    jacket = smin(jacket,sleeve,0.075);

    // Center back seam, two shaped back darts, and a short center vent.
    float back = 1.0-smoothstep(-0.36,-0.25,q.z);
    float dartX = 0.45+0.13*chest+0.04*hem;
    float seam = exp(-pow(q.x/0.009,2.0));
    seam += 0.65*exp(-pow((abs(q.x)-dartX)/0.012,2.0));
    jacket += 0.0035*seam*back;
    float vent = max(abs(q.x)-0.007,max(q.y+0.76,q.z+0.29));
    jacket = max(jacket,-vent);
    vec4 result = vec4(jacket,3.0,0.0,0.0);

    // Two separate folded pieces form each notched lapel.
    vec3 lapel = vec3(abs(q.x),q.y,q.z-(0.405+0.065*smoothstep(-0.3,0.9,q.y)));
    float fold = suitTriangle(lapel,vec2(0.34,0.88),vec2(0.65,0.64),vec2(0.045,-0.30),0.023)-0.009;
    float collar = suitTriangle(lapel,vec2(0.23,1.17),vec2(0.53,0.98),vec2(0.60,0.77),0.032)-0.008;
    fold = min(fold,collar);
    // Raised collar around the back of the neck, joined to the front folds.
    vec3 collarPos = q-vec3(0.0,1.15,-0.06);
    vec2 ring = vec2(abs(length(collarPos.xz)-0.40)-0.045,abs(collarPos.y)-0.11);
    float collarBack = min(max(ring.x,ring.y),0.0)+length(max(ring,0.0));
    collarBack = max(collarBack,q.z-0.08);
    fold = min(fold,collarBack);
    if(fold<result.x) result = vec4(fold,3.0,1.0,0.0);

    // Two hip flap pockets, and a single chest welt on the wearer's left.
    vec3 pocket = q-vec3(sign(q.x)*0.52,-0.64,0.411);
    pocket.xy = rot(pocket.xy,sign(q.x)*0.06);
    float flap = suitBox(pocket,vec3(0.22,0.083,0.016),0.023);
    vec3 welt = q-vec3(0.47,0.46,0.435);
    welt.xy = rot(welt.xy,-0.08);
    flap = min(flap,suitBox(welt,vec3(0.19,0.025,0.017),0.009));
    if(flap<result.x) result = vec4(flap,3.0,0.45,0.0);

    float buttons = 99.0;
    for(int i=0;i<2;i++)
    {
        vec3 b = q-vec3(-0.018,-0.32-0.46*float(i),0.431);
        buttons = min(buttons,suitButton(b,0.046));
    }
    for(int i=0;i<4;i++)
    {
        vec3 b = side-vec3(1.35,-1.02+0.069*float(i),-0.083);
        b.xz = rot(b.xz,0.7);
        buttons = min(buttons,suitButton(b,0.027));
    }
    if(buttons<result.x) result = vec4(buttons,7.0,0.0,0.0);

    float shirt = suitBox(q-vec3(0.0,0.05,-0.005),vec3(0.54,1.07,0.30),0.035);
    shirt = max(shirt,-sdEllipsoid(q-vec3(0.0,1.30,0.20),vec3(0.30,0.27,0.42)));
    if(shirt<result.x) result = vec4(shirt,6.0,0.0,0.0);
    float hand = suitHand(pos);
    if(hand<result.x) result = vec4(hand,1.0,0.0,0.0);

    // Matching trousers complete the body below the jacket during the orbit.
    vec3 leg = vec3(abs(pos.x),pos.yz);
    float trousers = sdEllipsoid(pos-vec3(0.0,-3.90,-0.04),vec3(0.72,0.48,0.34));
    vec2 segment = sdSegment(leg,vec3(0.37,-3.95,-0.025),vec3(0.39,-6.05,0.0));
    float legDist = segment.x-mix(0.30,0.19,segment.y);
    legDist = max(legDist,-6.13-pos.y);
    trousers = smin(trousers,legDist,0.12);
    if(trousers<result.x) result = vec4(trousers,8.0,0.0,0.0);
    float shoe = sdEllipsoid(leg-vec3(0.39,-6.23,0.12),vec3(0.23,0.17,0.40));
    if(shoe<result.x) result = vec4(shoe,9.0,0.0,0.0);
    return result;
}

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

// SDF of the girl. It is not as efficient as it should, 
// both in terms of performance and euclideanness of the
// returned distance. Among other things I tweaked the
// overal shape of the head though scaling right in the
// middle of the design process (see 1.02 and 1.04 numbers
// below). I should have backpropagated those adjustements
// to the  primitives themselves, but I didn't and now it's
// too late. So, I am paying some cost there.
//
// She is modeled to camera (her face's shape looks bad
// from other perspectives. She's made of five ellipsoids
// blended together for the face, a cone and three spheres
// for the nose, a torus for the teeh and two quadratic 
// curves for the lips. The neck is a cylinder, the hair
// is made of three quadratic curves that are repeated
// multiple times through domain repetition and each of
// them contains three more curves in order to make the
// braids. This study adds ears, a closed scalp, rear braids and a tailored
// outfit so the camera can travel around the complete character.
//
vec4 map( in vec3 pos, in float time, out float outMat, out vec3 uvw )
{
    outMat = 1.0;

    vec3 oriPos = pos;
    vec4 outfit = mapSuit(oriPos);
    if(oriPos.y < -1.90)
    {
        outMat = outfit.y;
        uvw = oriPos-vec3(0.0,-2.6,0.0);
        if(outMat<1.5) uvw = oriPos;
        return vec4(outfit.x,outfit.zw,1.0);
    }
    
    // head deformation and transformation
    pos.y /= 1.04;
    pos  = moveHead( pos, animHead, smoothstep(-1.4,-1.0,pos.y) );
    pos.x *= 1.04;
    pos.y /= 1.02;
    uvw = pos;

    // symmetric coord systems (sharp, and smooth)
    vec3 qos = vec3(abs(pos.x),pos.yz);
    vec3 sos = vec3(sabs(qos.x,0.005),pos.yz);
    
    // head
    float d = sdEllipsoid( pos-vec3(0.0,0.05,0.07), vec3(0.8,0.75,0.85) );
    
    // jaw
    vec3 mos = pos-vec3(0.0,-0.38,0.35); mos.yz = rot(mos.yz,0.4);
    mos.yz = rot(mos.yz,0.1*animData.z);
    float d2 = sdEllipsoid(mos-vec3(0,-0.17,0.16),
                 vec3(0.66+sclamp(mos.y*0.9-0.1*mos.z,-0.3,0.4),
                       0.43+sclamp(mos.y*0.5,-0.5,0.2),
                      0.50+sclamp(mos.y*0.3,-0.45,0.5)));
        
    // mouth hole
    d2 = smax(d2,-sdEllipsoid(mos-vec3(0,0.06,0.6+0.05*animData.z), vec3(0.16,0.035+0.05*animData.z,0.1)),0.01);
    
    // lower lip    
    vec4 b = sdBezier(vec3(abs(mos.x),mos.yz), 
                      vec3(0,0.01,0.61),
                      vec3(0.094+0.01*animData.z,0.015,0.61),
                      vec3(0.18-0.02*animData.z,0.06+animData.z*0.05,0.57-0.006*animData.z));
    float isLip = smoothstep(0.045,0.04,b.x+b.y*0.03);
    d2 = smin(d2,b.x - 0.027*(1.0-b.y*b.y)*smoothstep(1.0,0.4,b.y),0.02);
    d = smin(d,d2,0.19);

    // chicks
    d = smin(d,sdSphere(qos-vec3(0.2,-0.33,0.62),0.28 ),0.04);
    
    // Small ears close the side silhouette for an orbiting camera.
    vec3 earPos = qos-vec3(0.76,-0.13,0.02);
    float ear = sdEllipsoid(earPos,vec3(0.13,0.22,0.12));
    ear = smax(ear,-sdEllipsoid(earPos-vec3(0.065,0.01,0.045),vec3(0.07,0.15,0.09)),0.018);
    d = smin(d,ear,0.035);
    
    // eye sockets
    vec3 eos = sos-vec3(0.3,-0.04,0.7);
    eos.xz = rot(eos.xz,-0.2);
    eos.xy = rot(eos.xy,0.3);
    eos.yz = rot(eos.yz,-0.2);
    d2 = sdEllipsoid( eos-vec3(-0.05,-0.05,0.2), vec3(0.20,0.14-0.06*animData.x,0.1) );
    d = smax( d, -d2, 0.15 );

    eos = sos-vec3(0.32,-0.08,0.8);
    eos.xz = rot(eos.xz,-0.4);
    d2 = sdEllipsoid( eos, vec3(0.154,0.11,0.1) );
    d = smax( d, -d2, 0.05 );

    vec3 oos = qos - vec3(0.25,-0.06,0.42);
    
    // eyelid
    d2 = sdSphere( oos, 0.4 );
    oos.xz = rot(oos.xz, -0.2);
    oos.xy = rot(oos.xy, 0.2);
    vec3 tos = oos;        
    oos.yz = rot(oos.yz,-0.6+0.58*animData.x);

    //eyebags
    tos = tos-vec3(-0.02,0.06,0.2+0.02*animData.x);
    tos.yz = rot(tos.yz,0.8);
    tos.xy = rot(tos.xy,-0.2);
    d = smin( d, sdTorus(tos,0.29,0.01), 0.03 );
    
    // eyelids
    eos = qos - vec3(0.33,-0.07,0.53);
    eos.xy = rot(eos.xy, 0.2);
    eos.yz = rot(eos.yz,0.35-0.25*animData.x);
    d2 = smax(d2-0.005, -max(oos.y+0.098,-eos.y-0.025), 0.02 );
    d = smin( d, d2, 0.012 );

    // eyelashes
    oos.x -= 0.01;
    float xx = clamp( oos.x+0.17,0.0,1.0);
    float ra = 0.35 + 0.1*sqrt(xx/0.2)*(1.0-smoothstep(0.3,0.4,xx))*(0.84+0.16*sin(xx*256.0));
    float rc = 0.18/(1.0-0.7*smoothstep(0.15,0.5,animData.x));
    oos.y -= -0.18 - (rc-0.18)/1.8;
    d2 = (1.0/1.8)*sdArc( oos.xy*vec2(1.0,1.8), vec2(0.9,sqrt(1.0-0.9*0.9)), rc )-0.001;
    float deyelashes = max(d2,length(oos.xz)-ra)-0.003;
    
    // nose
    eos = pos-vec3(0.0,-0.079+animData.y*0.005,0.86);
    eos.yz = rot(eos.yz,-0.23);
    float h = smoothstep(0.0,0.26,-eos.y);
    d2 = sdCone( eos-vec3(0.0,-0.02,0.0), vec2(0.03,-0.25) )-0.04*h-0.01;
    eos.x = sqrt(eos.x*eos.x + 0.001);
    d2 = smin( d2, sdSphere(eos-vec3(0.0, -0.25,0.037),0.06 ), 0.07 );
    d2 = smin( d2, sdSphere(eos-vec3(0.1, -0.27,0.03 ),0.04 ), 0.07 );
    d2 = smin( d2, sdSphere(eos-vec3(0.0, -0.32,0.05 ),0.025), 0.04 );        
    d2 = smax( d2,-sdSphere(eos-vec3(0.07,-0.31,0.038),0.02 ), 0.035 );
    d = smin(d,d2,0.05-0.03*h);
    
    // mouth
    eos = pos-vec3(0.0,-0.38+animData.y*0.003+0.01*animData.z,0.71);
    tos = eos-vec3(0.0,-0.13,0.06);
    tos.yz = rot(tos.yz,0.2);
    float dTeeth = sdTorus(tos,0.15,0.015);
    eos.yz = rot(eos.yz,-0.5);
    eos.x /= 1.04;

    // nose-to-upperlip connection
    d2 = sdCone( eos-vec3(0,0,0.03), vec2(0.14,-0.2) )-0.03;
    d2 = max(d2,-(eos.z-0.03));
    d = smin(d,d2,0.05);

    // upper lip
    eos.x = abs(eos.x);
    b = sdBezier(eos, vec3(0.00,-0.22,0.17),
                      vec3(0.08,-0.22,0.17),
                      vec3(0.17-0.02*animData.z,-0.24-0.01*animData.z,0.08));
    d2 = length(b.zw/vec2(0.5,1.0)) - 0.03*clamp(1.0-b.y*b.y,0.0,1.0);
    d = smin(d,d2,0.02);
    isLip = max(isLip,(smoothstep(0.03,0.005,abs(b.z+0.015+abs(eos.x)*0.04))
                 -smoothstep(0.45,0.47,eos.x-eos.y*1.15)));

    // valley under nose
    vec2 se = sdSegment(pos, vec3(0.0,-0.45,1.01),  vec3(0.0,-0.47,1.09) );
    d2 = se.x-0.03-0.06*se.y;
    d = smax(d,-d2,0.04);
    isLip *= smoothstep(0.01,0.03,d2);

    // neck
    se = sdSegment(pos, vec3(0.0,-0.65,0.0), vec3(0.0,-1.7,-0.1) );
    d2 = se.x - 0.38;

    // shoulders
    se = sdSegment(sos, vec3(0.0,-1.55,0.0), vec3(0.6,-1.65,0.0) );
    d2 = smin(d2,se.x-0.21,0.1);
    d = smin(d,d2,0.4);
        
    // register eyelases now
    vec4 res = vec4( d, isLip, 0, 0 );
    if( deyelashes<res.x )
    {
        res.x = deyelashes*0.8;
        res.yzw = vec3(0.0,1.0,0.0);
    }
    // register teeth now
    if( dTeeth<res.x )
    {
        res.x = dTeeth;
        outMat = 5.0;
    }
 
    // eyes
    pos.x /=1.05;        
    eos = qos-vec3(0.25,-0.06,0.42);
    d2 = sdSphere(eos,0.4);
    if( d2<res.x ) 
    { 
        res.x = d2;
         outMat = 2.0;
        uvw = pos;
    }
        
    // hair
    {
        vec2 occ_id, tmp;
        qos = pos; qos.x=abs(pos.x);

        vec4 pres = sdHair(pos,vec3(-0.3, 0.55,0.8), 
                               vec3( 0.95, 0.7,0.85), 
                               vec3( 0.4,-1.45,0.95),
                               -0.9,occ_id);

        vec4 pres2 = sdHair(pos,vec3(-0.4, 0.6,0.55), 
                                vec3(-1.0, 0.4,0.2), 
                                vec3(-0.6,-1.4,0.7),
                                0.6,tmp);
        if( pres2.x<pres.x ) { pres=pres2; occ_id=tmp;  occ_id.y+=40.0;}

        pres2 = sdHair(qos,vec3( 0.4, 0.7,0.4), 
                           vec3( 1.0, 0.5,0.45), 
                           vec3( 0.4,-1.45,0.55),
                           -0.2,tmp);
        if( pres2.x<pres.x ) { pres=pres2; occ_id=tmp;  occ_id.y+=80.0;}

        pres2 = sdRearBraids(pos,tmp);
        if(pres2.x<pres.x) { pres=pres2; occ_id=tmp; }

        pres.x *= 0.8;
        if( pres.x<res.x )
        {
            res = vec4( pres.x, occ_id.y, 0.0, occ_id.x );
            uvw = pres.yzw;
            outMat = 4.0;
        }
    }

    // A continuous scalp supplies the crown and rear hair under the braids.
    vec3 scalpPos = pos-vec3(0.0,0.07,0.015);
    float scalp = sdEllipsoid(scalpPos,vec3(0.84,0.79,0.89));
    float hairline = mix(-0.50,0.54,smoothstep(-0.16,0.58,pos.z));
    scalp = max(scalp,hairline-pos.y);
    if(scalp<res.x)
    {
        res = vec4(scalp,0.0,0.0,1.0);
        outMat = 10.0;
        uvw = pos;
    }

    if(outfit.x<res.x)
    {
        res = vec4(outfit.x,outfit.zw,1.0);
        outMat = outfit.y;
        uvw = oriPos-vec3(0.0,-2.6,0.0);
        if(outMat<1.5) uvw = oriPos;
    }

    return res;
}

// SDF of the girl again, but with extra high frequency
// modeling detail. While the previous one is used for
// raymarching and shadowing, this one is used for normal
// computation. This separation is conceptually equivalent
// to decoupling detail from base geometry with "normal
// maps", but done in 3D and with SDFs, which is way
// simpler and can be done corretly (something rarely seen
// in 3D engines) without any complexity.
vec4 mapD( in vec3 pos, in float time )
{
    float matID;
    vec3 uvw;
    vec4 h = map(pos, time, matID, uvw);
    
    if( matID<1.5 ) // skin
    {
        // pores
        float d = noise1(iChannel0,80.0*uvw);
        h.x += SKIN_DETAIL*d*d;
    }
    else if( matID>3.5 && matID<4.5 ) // hair
    {
        // some random displacement to evoke hairs
        float te = textureLod(iChannel2,vec2(0.25*atan(uvw.x,uvw.y),4.0*uvw.z),0.0).x;
        h.x -= HAIR_DETAIL*te;
    }
    else if(matID>9.5) // fine swept strands on the crown
    {
        h.x += 0.00055*sin(92.0*atan(uvw.x,uvw.z)+6.0*uvw.y);
    }
    return h;
}

// Computes the normal of the girl's surface (the gradient
// of the SDF). The implementation is weird because of the
// technicalities of the WebGL API that forces us to do
// some trick to prevent code unrolling. More info here:
//
// https://iquilezles.org/articles/normalsSDF
//
vec3 calcNormal( in vec3 pos, in float time )
{
    // A symmetric tetrahedral gradient avoids a directional bias in highlights.
    const float eps = 0.0008;
    vec3 n = vec3(0.0);
    for( int i=ZERO; i<4; i++ )
    {
        vec3 e = 0.57735027*(2.0*vec3(float(((i+3)>>1)&1),
                                    float((i>>1)&1), float(i&1))-1.0);
        n += e*mapD(pos+eps*e,time).x;
    }
    return normalize(n);
}

// Compute soft shadows for a given light, with a single
// ray insead of using montecarlo integration or shadowmap
// blurring. More info here:
//
// https://iquilezles.org/articles/rmshadows
//
float calcSoftshadow( in vec3 ro, in vec3 rd, in float mint, in float tmax, in float time, float k )
{
    // first things first - let's do a bounding volume test
    vec2 sph = iCylinderY( ro, rd, 1.8 );
  //vec2 sph = iConeY(ro-vec3(-0.05,3.7,0.35),rd,0.08);
    tmax = min(tmax,sph.y);

    // raymarch and track penumbra    
    float res = 1.0;
    float t = mint;
    for( int i=0; i<128; i++ )
    {
        float kk; vec3 kk2;
        float h = map( ro + rd*t, time, kk, kk2 ).x;
        res = min( res, k*h/t );
        t += clamp( h, 0.005, 0.1 );
        if( res<0.002 || t>tmax ) break;
    }
    return max( res, 0.0 );
}

// Computes convexity for our girl SDF, which can be used
// to approximate ambient occlusion. More info here:
//
// https://iquilezles.org/www/material/nvscene2008/rwwtt.pdf
//
float calcOcclusion( in vec3 pos, in vec3 nor, in float time )
{
    // Deterministic normal probes keep contact shadows smooth in a single frame.
    float kk; vec3 kk2;
    float ao = 0.0;
    float weight = 1.0;
    for( int i=ZERO; i<5; i++ )
    {
        float h = 0.012+0.032*float(i);
        float d = map(pos+nor*h,time,kk,kk2).x;
        ao += max(h-d,0.0)*weight;
        weight *= 0.65;
    }
    return clamp(1.0-3.2*ao,0.15,1.0);
}

// Computes the intersection point between our girl SDF and
// a ray (coming form the camera in this case). It's a
// traditional and basic/uncomplicated SDF raymarcher. More
// info here:
//
// https://iquilezles.org/www/material/nvscene2008/rwwtt.pdf
//
vec2 intersect( in vec3 ro, in vec3 rd, in float tmax, in float time, out vec3 cma, out vec3 uvw )
{
    cma = vec3(0.0);
    uvw = vec3(0.0);
    float matID = -1.0;

    float t = 1.0;
    
    // bounding volume test first
    vec2 sph = iCylinderY( ro, rd, 1.8 );
  //vec2 sph = iConeY(ro-vec3(-0.05,3.7,0.35),rd,0.08);
    if( sph.y<0.0 ) return vec2(-1.0);
    
    // clip raymarch space to bonding volume
    tmax = min(tmax,sph.y);
    t    = max(1.0, sph.x);
    
    // raymarch
    for( int i=0; i<320; i++ )
    {
        vec3 pos = ro + t*rd;

        float tmp;
        vec4 h = map(pos,time,tmp,uvw);
        if( h.x<0.00035 )
        {
            cma = h.yzw;
            matID = tmp;
            break;
        }
        // The blended, distorted surfaces are not exact distance bounds.
        t += h.x*0.8;
        if( t>tmax ) break;
    }

    return vec2(t,matID);
}

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

// Renders the girl. It finds the ray-girl intersection
// point, computes the normal at the intersection point,
// computes the ambient occlusion approximation, does per
// material setup (color, specularity, subsurface
// coefficient and paints some fake occlusion), and finally
// does the lighting computations.
//
// Lighting is not based on pathtracing. Instead the bounce
// light occlusion signals are created manually (placed
// and sized by hand). The subsurface scattering in the
// nose area is also painted by hand. There's not much
// attention to the physicall correctness of the light
// response and materials, but generally all signal do
// follow physically based rendering practices.
//
vec3 renderGirl( in vec3 ro, in vec3 rd, in float tmax, in vec3 col, in float time )
{
    // --------------------------
    // find ray-girl intersection
    // --------------------------
    vec3 cma, uvw;
    vec2 tm = intersect( ro, rd, tmax, time, cma, uvw );

    // --------------------------
    // shading/lighting    
    // --------------------------
    if( tm.y>0.0 )
    {
        vec3 pos = ro + tm.x*rd;
        vec3 nor = calcNormal(pos, time);

        float ks = 1.0;
        float se = 16.0;
        float tinterShadow = 0.0;
        float sss = 0.0;
        float focc = 1.0;
        //float frsha = 1.0;

        // --------------------------
        // material
        // --------------------------
        if( tm.y<1.5 ) // skin
        {
            vec3 qos = vec3(abs(uvw.x),uvw.yz);

            // base skin color
            float blush = (1.0-smoothstep(0.05,0.38,length(qos.xy-vec2(0.42,-0.3))))
                        + (1.0-smoothstep(0.02,0.15,length((qos.xy-vec2(0,-0.29))/vec2(1.4,1))));
            col = mix(vec3(0.38,0.215,0.15),vec3(0.41,0.16,0.115),0.42*clamp(blush,0.0,1.0));
            
            // fix that ugly highlight
            col *= 1.0-0.04*(1.0-smoothstep(0.0,0.13,length((qos.xy-vec2(0,-0.49))/vec2(2,1))));
                
            // lips
            col = mix(col,vec3(0.24,0.07,0.075),clamp(cma.x,0.0,1.0)*step(-0.7,qos.y));
            
            // eyelashes
            col = mix(col,vec3(0.04,0.02,0.02)*0.6,0.9*cma.y);

            // fake skin drag
            uvw.y += 0.025*animData.x*smoothstep(0.3,0.1,length(uvw-vec3(0.0,0.1,1.0)));
            uvw.y -= 0.005*animData.y*smoothstep(0.09,0.0,abs(length((uvw.xy-vec2(0.0,-0.38))/vec2(2.5,1.0))-0.12));
            
            // freckles
            vec2 ti = floor(9.0+uvw.xy/0.04);
            vec2 uv = fract(uvw.xy/0.04)-0.5;
            float te = fract(111.0*sin(1111.0*ti.x+1331.0*ti.y));
            te = smoothstep(0.9,1.0,te)*exp(-dot(uv,uv)*24.0); 
            col *= mix(vec3(1.0),vec3(0.78,0.65,0.55),0.4*te);

            // Broad, continuous skin highlights instead of random bright pixels.
            ks = 0.32+0.04*noise1(iChannel0,uvw*12.0);
            se = 32.0;
            tinterShadow = 1.0;
            sss = 1.0;
            ks *= 1.0 + cma.x;
            
            // black top
            col *= 1.0-smoothstep(0.48,0.51,uvw.y);
            
            // makeup
            float d2 = sdEllipsoid(qos-vec3(0.25,-0.03,0.43),vec3(0.37,0.42,0.4));
            col = mix(col,vec3(0.11,0.045,0.035),0.45*(1.0-smoothstep(0.0,0.03,d2)));

            // eyebrows
            {
            #if 0
            // youtube video version
            vec4 be = sdBezier( qos, vec3(0.165+0.01*animData.x,0.105-0.02*animData.x,0.89),
                                     vec3(0.37,0.18-0.005*animData.x,0.82+0.005*animData.x), 
                                     vec3(0.53,0.15,0.69) );
            float ra = 0.005 + 0.015*sqrt(be.y);
            #else
            // fixed version
            vec4 be = sdBezier( qos, vec3(0.16+0.01*animData.x,0.11-0.02*animData.x,0.89),
                                     vec3(0.37,0.18-0.005*animData.x,0.82+0.005*animData.x), 
                                     vec3(0.53,0.15,0.69) );
            float ra = 0.005 + 0.01*sqrt(1.0-be.y);
            #endif
            float dd = 1.0+0.012*(0.7*sin((sin(qos.x*3.0)/3.0-0.5*qos.y)*350.0)+
                                 0.3*sin((qos.x-0.8*qos.y)*250.0+1.0));
            float d = be.x - ra*dd;
            float mask = 1.0-smoothstep(-0.005,0.01,d);
            col = mix(col,vec3(0.04,0.02,0.02),mask*dd );
            }

            // fake occlusion
            focc = 0.2+0.8*pow(1.0-smoothstep(-0.4,1.0,uvw.y),2.0);
            focc *= 0.5+0.5*smoothstep(-1.5,-0.75,uvw.y);
            focc *= 1.0-smoothstep(0.4,0.75,abs(uvw.x));
            focc *= 1.0-0.4*smoothstep(0.2,0.5,uvw.y);
            
            focc *= 1.0-smoothstep(1.0,1.3,1.7*uvw.y-uvw.x);
            focc = mix(0.65,1.0,clamp(focc,0.0,1.0));
            
            //frsha = 0.0;
        }
        else if( tm.y<2.5 ) // eye
        {
            // The eyes are fake in that they aren't 3D. Instead I simply
            // stamp a 2D mathematical drawing of an iris and pupil. That
            // includes the highlight and occlusion in the eyesballs.
            
            sss = 1.0;

            vec3 qos = vec3(abs(uvw.x),uvw.yz);
            float ss = sign(uvw.x);
            
            // iris animation
            float dt = floor(time*1.1);
            float ft = fract(time*1.1);
            vec2 da0 = sin(1.7*(dt+0.0)) + sin(2.3*(dt+0.0)+vec2(1.0,2.0));
            vec2 da1 = sin(1.7*(dt+1.0)) + sin(2.3*(dt+1.0)+vec2(1.0,2.0));
            vec2 da = mix(da0,da1,smoothstep(0.9,1.0,ft));

            float gg = animEye(time);
            da *= 1.0+0.5*gg;
            qos.yz = rot(qos.yz,da.y*0.004-0.01);
            qos.xz = rot(qos.xz,da.x*0.004*ss-gg*ss*(0.03-step(0.0,ss)*0.014)+0.02);

            vec3 eos = qos-vec3(0.31,-0.055 - 0.03*animData.x,0.45);
            
            // iris
            float r = length(eos.xy)+0.005;
            float a = atan(eos.y,ss*eos.x);
            vec3 iris = vec3(0.09,0.0315,0.0135);
            iris += iris*3.0*(1.0-smoothstep(0.0,1.0, abs((a+3.14159)-2.5) ));
            iris *= 0.75+0.25*textureLod(iChannel2,vec2(r,a/6.2831),0.0).x;
            // base color
            col = vec3(0.52,0.50,0.45);
            col *= 0.1+0.9*smoothstep(0.10,0.114,r);
            col = mix( col, iris, 1.0-smoothstep(0.095,0.10,r) );
            col *= smoothstep(0.05,0.07,r);
            
            // fake occlusion backed in
            float edis = length((vec2(abs(uvw.x),uvw.y)-vec2(0.31,-0.07))/vec2(1.3,1.0));
            col *= mix( vec3(1.0), vec3(0.4,0.2,0.1), linearstep(0.07,0.16,edis) );

            // fake highlight
            qos = vec3(abs(uvw.x),uvw.yz);
            col += (0.5-gg*0.3)*(1.0-smoothstep(0.0,0.02,length(qos.xy-vec2(0.29-0.05*ss,0.0))));
            
            se = 128.0;
            ks = 0.65;

            // fake occlusion
            focc = 0.2+0.8*pow(1.0-smoothstep(-0.4,1.0,uvw.y),2.0);
            focc *= 1.0-linearstep(0.10,0.17,edis);
            focc = mix(0.55,1.0,clamp(focc,0.0,1.0));
            //frsha = 0.0;
        }
        else if( tm.y<3.5 ) // taupe jacquard blazer
        {
            sss = 0.0;
            vec3 weights = pow(abs(nor),vec3(6.0));
            weights /= max(dot(weights,vec3(1.0)),0.0001);
            float brocade = dot(weights,vec3(suitBrocade(uvw.zy),suitBrocade(uvw.xz),suitBrocade(uvw.xy)));
            float weave = noise1(iChannel0,uvw*90.0);
            col = vec3(0.21,0.183,0.15)*(0.87+0.22*brocade)*(0.98+0.04*weave);
            col *= 1.0-0.14*cma.x;
            ks = 0.32+0.25*brocade;
            se = 36.0;
            focc = 0.86;
        }
        else if( tm.y<4.5 )// hair
        {
            sss = 0.0;
            col = (sin(cma.x)>0.7) ? vec3(0.055,0.024,0.042) : vec3(0.032,0.014,0.008);
            float te = textureLod(iChannel2,vec2(0.25*atan(uvw.x,uvw.y),4.0*uvw.z),0.0).x;
            col *= 0.9+0.2*te;
            ks = 0.65;
            se = 56.0;
            
            // fake occlusion
            focc = 0.65+0.35*clamp(cma.z*4.0,0.0,1.0);
            //frsha = 1.0-smoothstep(-1.3,-0.8,uvw.y);
            //frsha *= 1.0-smoothstep(-1.20,-0.2,-uvw.z);
        }
        else if( tm.y<5.5 )// teeth
        {
            sss = 1.0;
            col = vec3(0.3);
            ks *= 1.5;
            //frsha = 0.0;
        }
        else if(tm.y<6.5) // ivory blouse inside the open front
        {
            col = vec3(0.60,0.54,0.43);
            float placket = 1.0-smoothstep(0.012,0.025,abs(uvw.x));
            col *= 1.0-0.06*placket;
            ks = 0.12;
            se = 18.0;
            focc = 0.88;
        }
        else if(tm.y<7.5) // horn buttons, with modeled holes
        {
            col = vec3(0.115,0.091,0.062);
            ks = 0.7;
            se = 64.0;
        }
        else if(tm.y<8.5) // matching tailored trousers
        {
            col = vec3(0.105,0.09,0.072)*(0.97+0.06*noise1(iChannel0,uvw*80.0));
            ks = 0.15;
            se = 22.0;
        }
        else if(tm.y<9.5) // dark leather shoes
        {
            col = vec3(0.025,0.019,0.015);
            ks = 0.65;
            se = 72.0;
        }
        else // continuous hair at the crown and back of the skull
        {
            float strands = 0.5+0.5*sin(92.0*atan(uvw.x,uvw.z)+6.0*uvw.y);
            col = vec3(0.023,0.010,0.006)*(0.88+0.20*strands);
            ks = 0.5;
            se = 60.0;
            focc = 0.85;
        }

        float fre = clamp(1.0+dot(nor,rd),0.0,1.0);
        float occ = clamp(focc*calcOcclusion(pos,nor,time),0.0,1.0);

        // A warm large key, a cool fill and a restrained back light.
        vec3 lig = normalize(vec3(0.9,1.1,1.3));
        vec3 hal = normalize(lig-rd);
        float ndl = dot(nor,lig);
        float sha = calcSoftshadow(pos+nor*0.002,lig,0.001,3.0,time,3.0);
        sha = mix(sha,0.22+0.78*sha,tinterShadow);
        float wrap = mix(max(ndl,0.0),clamp((ndl+0.3)/1.3,0.0,1.0),0.45*sss);
        vec3 shadowTint = mix(vec3(sha),vec3(sha,sha*0.92,sha*0.86),0.35*tinterShadow);
        vec3 ambient = vec3(0.36,0.36,0.32)*(0.6+0.4*nor.y)*occ;
        float fill = max(dot(nor,normalize(vec3(-0.85,0.25,0.9))),0.0);
        vec3 illumination = ambient + vec3(0.35,0.43,0.50)*fill*occ;
        illumination += vec3(2.05,1.78,1.47)*wrap*shadowTint;
        illumination += vec3(0.23,0.13,0.07)*max(-nor.y,0.0)*occ;
        // A second softbox keeps the back tailoring readable through the orbit.
        float backLight = max(dot(nor,normalize(vec3(-0.65,0.8,-1.15))),0.0);
        illumination += vec3(1.05,0.94,0.80)*backLight*occ;

        float rim = pow(max(dot(nor,normalize(vec3(-0.5,0.5,-0.8))),0.0),2.0);
        illumination += vec3(1.0,0.58,0.25)*rim*0.75;
        float specular = ks*pow(max(dot(nor,hal),0.0),se)*sha*(0.12+0.22*pow(fre,5.0));
        vec3 sheen = vec3(1.0,0.88,0.72)*specular;
        if(tm.y>3.5 && tm.y<4.5) sheen += vec3(0.13,0.073,0.034)*rim*occ;
        if(tm.y>2.5 && tm.y<3.5) sheen += vec3(0.047,0.038,0.025)*pow(fre,3.0)*occ;
        col = col*illumination + sheen;
        // Gentle warm transmission at the thin edges of the skin.
        col += vec3(0.13,0.028,0.012)*sss*pow(fre,3.0)*(0.4+0.6*sha);
    }
        
    return col;
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

// A world-space environment moves with the view during the camera orbit.
vec3 portraitBackground(in vec3 rd)
{
    vec3 col = mix(vec3(0.013,0.024,0.019),vec3(0.065,0.077,0.042),smoothstep(-0.4,0.6,rd.y));
    vec3 sun = normalize(vec3(0.9,0.5,-0.7));
    col += vec3(0.19,0.13,0.052)*pow(max(dot(rd,sun),0.0),8.0);
    float canopy = 0.5+0.5*sin(rd.x*12.0+sin(rd.z*8.0))*sin(rd.y*15.0+rd.z*6.0);
    col += vec3(0.012,0.023,0.008)*canopy;
    for(int i=0;i<48;i++)
    {
        vec3 h = hash3(uint(i)+173u);
        float angle = 6.2831853*h.x;
        vec3 center = normalize(vec3(sin(angle),mix(-0.35,0.85,h.y),cos(angle)));
        float radius = mix(0.016,0.065,h.z);
        float d = length(rd-center);
        float disc = 1.0-smoothstep(radius*0.5,radius*1.6,d);
        float glow = exp(-d*d/(radius*radius*5.0));
        col += mix(vec3(0.07,0.09,0.025),vec3(0.35,0.24,0.10),h.z)*(0.55*disc+0.15*glow);
    }
    return col;
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

vec3 portraitTonemap(in vec3 linearColor)
{
    // Compress highlights in linear light, then convert to display gamma.
    vec3 x = max(linearColor*PORTRAIT_EXPOSURE,vec3(0.0));
    vec3 mapped = clamp((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14),0.0,1.0);
    return pow(mapped,vec3(1.0/2.2));
}

void mainImage(out vec4 fragColor,in vec2 fragCoord)
{
    float time = iTime+2.0;
    float turn = animTurn(time);
    animData.x = animBlink(time,0.0);
    animData.y = animBlink(time-0.02,1.0);
    animData.z = -0.25+0.2*(1.0-turn)*smoothstep(-0.3,0.9,sin(time*1.1))+0.05*cos(time*2.7);
    animHead = vec3(sin(time*0.5),sin(time*0.3),-cos(time*0.2));
    animHead = animHead*animHead*animHead;
    animHead.x = -0.025*animHead.x+0.2*(0.7+0.3*turn);
    animHead.y = 0.1+0.02*animHead.y*animHead.y*animHead.y;
    animHead.z = -0.03*(0.5+0.5*animHead.z)-(1.0-turn)*0.05;

    vec3 ro;
    mat3 camera = portraitCamera(iTime,ro);
    vec3 total = vec3(0.0);
    for(int m=ZERO; m<AA; m++)
    for(int n=ZERO; n<AA; n++)
    {
        vec2 offset = (vec2(float(m),float(n))+0.5)/float(AA)-0.5;
        vec2 p = (2.0*(fragCoord+offset)-iResolution.xy)/iResolution.y;
        // Preserve the entire head in narrow windows as well as landscape.
        float fit = max(1.0,0.95*iResolution.y/iResolution.x);
        vec3 rd = camera*normalize(vec3(p*fit,2.70));
        vec3 background = portraitBackground(rd);
        total += renderGirl(ro,rd,20.0,background,time);
    }
    total /= float(AA*AA);
    vec2 q = (2.0*fragCoord-iResolution.xy)/iResolution.xy;
    total *= 1.0-0.13*smoothstep(0.35,1.6,dot(q,q));
    fragColor = vec4(portraitTonemap(total),1.0);
}
