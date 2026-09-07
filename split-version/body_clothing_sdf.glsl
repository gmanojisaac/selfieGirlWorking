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

vec4 mapSuit(vec3 pos)
{
    vec3 q = pos-vec3(0.0,-2.6,0.0);
    float chest = smoothstep(-0.15,0.9,q.y);
    float hem = 1.0-smoothstep(-1.1,-0.55,q.y);
    float width = 0.67+0.20*chest+0.16*hem;
    vec3 body = q;
    // A fuller upper back encloses the neck; shaped quarters flare below the waist.
    body.z += 0.055*chest;
    body.z += 0.016*sin(q.y*7.0+abs(q.x)*5.0)*smoothstep(0.40,0.85,abs(q.x));
    body.z += 0.009*sin(q.y*17.0-abs(q.x)*8.0)*exp(-pow((q.y+0.42)*2.5,2.0));
    float jacket = suitBox(body,vec3(width-0.16,1.13,0.28+0.065*chest),0.16);

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
    sleeve += (0.010*sin(30.0*side.y+8.0*side.z)+0.004*sin(57.0*side.y-11.0*side.z))*exp(-side.y*side.y*14.0);
    sleeve = max(sleeve,-1.17-side.y);
    jacket = smin(jacket,sleeve,0.075);

    // Center back seam, two shaped back darts, and a short center vent.
    float back = 1.0-smoothstep(-0.36,-0.25,q.z);
    float dartX = 0.45+0.13*chest+0.04*hem;
    float seam = exp(-pow(q.x/0.009,2.0));
    seam += 0.65*exp(-pow((abs(q.x)-dartX)/0.012,2.0));
    jacket += 0.0035*seam*back;
    // Shallow overlapping vent: retain cloth behind the slit.
    float vent = max(abs(q.x)-0.006,max(q.y+0.76,abs(q.z+0.415)-0.040));
    jacket = max(jacket,-vent);
    vec4 result = vec4(jacket,3.0,0.0,0.0);

    // Two separate folded pieces form each notched lapel.
    float roll = 0.026*sin(3.0*clamp(q.y+0.32,0.0,1.40)) + 0.020*smoothstep(0.12,0.55,abs(q.x));
    vec3 lapel = vec3(abs(q.x),q.y,q.z-(0.425+0.065*smoothstep(-0.3,0.9,q.y)+roll));
    float fold = suitTriangle(lapel,vec2(0.34,0.88),vec2(0.66,0.62),vec2(0.045,-0.34),0.017)-0.007;
    float collar = suitTriangle(lapel,vec2(0.23,1.17),vec2(0.53,0.98),vec2(0.60,0.77),0.024)-0.007;
    fold = min(fold,collar);
    // Raised collar around the back of the neck, joined to the front folds.
    vec3 collarPos = q-vec3(0.0,1.15,-0.06);
    vec2 ring = vec2(abs(length(collarPos.xz)-0.40)-0.045,abs(collarPos.y)-0.11);
    float collarBack = min(max(ring.x,ring.y),0.0)+length(max(ring,0.0));
    collarBack = max(collarBack,q.z-0.08);
    fold = min(fold,collarBack);
    if(fold<result.x) result = vec4(fold,3.0,1.0,0.0);

    // Two hip flap pockets, and a single chest welt on the wearer's left.
    vec3 pocket = q-vec3(sign(q.x)*0.52,-0.64,0.461);
    pocket.z += 0.022*pow(pocket.x/0.24,2.0);
    pocket.xy = rot(pocket.xy,sign(q.x)*0.06);
    float flap = suitBox(pocket,vec3(0.22,0.067,0.011),0.025);
    vec3 welt = q-vec3(0.47,0.46,0.465);
    welt.xy = rot(welt.xy,-0.08);
    flap = min(flap,suitBox(welt,vec3(0.19,0.025,0.017),0.009));
    if(flap<result.x) result = vec4(flap,3.0,0.45,0.0);

    float buttons = 99.0;
    for(int i=0;i<2;i++)
    {
        vec3 b = q-vec3(-0.018,-0.32-0.46*float(i),0.459);
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
