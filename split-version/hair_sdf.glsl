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

