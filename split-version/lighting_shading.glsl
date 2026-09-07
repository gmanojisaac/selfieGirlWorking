// Tone-on-tone damask: alternating leaves, curling stems and small woven petals.
float suitBrocade(vec2 uv)
{
    vec2 cell = uv*9.0;
    cell.x += 0.5*mod(floor(cell.y),2.0);
    vec2 p = fract(cell)-0.5;
    float angle = atan(p.y,p.x);
    float radius = length(p);
    float petal = 0.26+0.055*cos(4.0*angle+0.7*sin(angle*2.0));
    float flower = 1.0-smoothstep(0.016,0.054,abs(radius-petal));
    float inner = 1.0-smoothstep(0.012,0.037,abs(radius-petal*0.56));
    float vine = 1.0-smoothstep(0.012,0.039,abs(p.x-0.17*sin(p.y*8.0)));
    vec2 leaf = vec2(abs(p.x)-0.23,p.y+0.13*sin(p.x*8.0));
    float leaves = 1.0-smoothstep(0.65,1.0,length(leaf/vec2(0.10,0.20)));
    // Fade to a flat weave at tile edges so finite-difference normals do not
    // turn the staggered cell boundaries into horizontal ridges.
    float border = 1.0-smoothstep(0.36,0.49,max(abs(p.x),abs(p.y)));
    return border*clamp(0.45*flower+0.20*inner+0.16*vine+0.35*leaves,0.0,1.0);
}

float suitStitches(vec3 q, float piece)
{
    vec2 p = vec2(abs(q.x),q.y);
    float edge = min(suitEdge(p,vec2(0.34,0.88),vec2(0.66,0.62)),
                     suitEdge(p,vec2(0.66,0.62),vec2(0.045,-0.34)));
    edge = min(edge,suitEdge(p,vec2(0.045,-0.34),vec2(0.34,0.88)));
    float lapel = (1.0-smoothstep(0.003,0.007,abs(edge-0.018)))*step(0.8,piece);
    vec2 pocket = vec2(abs(q.x)-0.52,q.y+0.64);
    float pocketEdge = abs(max(abs(pocket.x)-0.211,abs(pocket.y)-0.060));
    float flap = (1.0-smoothstep(0.002,0.007,pocketEdge))*step(0.2,piece)*(1.0-step(0.8,piece));
    float dash = smoothstep(-0.15,0.30,sin((q.y+abs(q.x))*290.0));
    return max(lapel,flap)*dash*smoothstep(0.30,0.43,q.z);
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
    else if( matID>2.5 && matID<3.5 ) // woven ivory cloth relief
    {
        float detail = smoothstep(240.0,720.0,iResolution.y);
        float damask = suitBrocade(vec2(uvw.x+0.7*uvw.z,uvw.y));
        float threads = sin(uvw.y*220.0)*sin((uvw.x+uvw.z)*205.0);
        h.x += detail*(0.0026*damask+0.00020*threads);
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
    float t = max(mint,0.0001); // Keep k*h/t finite even if mint is zero.
    if( !clipCharacterBounds(ro,rd,t,tmax) ) return 1.0;

    // raymarch and track penumbra    
    float res = 1.0;
    for( int i=0; i<128; i++ )
    {
        float kk; vec3 kk2;
        float h = map( ro + rd*t, time, kk, kk2 ).x;
        res = min( res, k*h/t );
        t += clamp( h, 0.005, 0.1 );
        if( res<0.002 || t>=tmax ) break;
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
        else if( tm.y<3.5 ) // ivory silk-linen jacquard blazer
        {
            sss = 0.0;
            float brocade = suitBrocade(vec2(uvw.x+0.7*uvw.z,uvw.y));
            float weave = noise1(iChannel0,uvw*75.0);
            float yarn = noise1(iChannel0,uvw*11.0);
            col = vec3(0.47,0.425,0.335)*(0.92+0.16*brocade)*(0.975+0.05*weave);
            col *= 0.97+0.06*yarn;
            col *= 1.0-0.045*cma.x;
            float stitch = suitStitches(uvw,cma.x);
            col *= 1.0-0.13*stitch;
            ks = 0.95+0.45*brocade;
            se = 19.0;
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
        float cloth = step(2.5,tm.y)*(1.0-step(3.5,tm.y));
        vec3 illumination = ambient*mix(1.0,0.82,cloth) + vec3(0.28,0.34,0.39)*fill*occ;
        illumination += vec3(2.10,1.86,1.49)*wrap*shadowTint;
        illumination += vec3(0.23,0.13,0.07)*max(-nor.y,0.0)*occ;
        // A second softbox keeps the back tailoring readable through the orbit.
        float backLight = max(dot(nor,normalize(vec3(-0.65,0.8,-1.15))),0.0);
        illumination += vec3(0.48,0.39,0.28)*backLight*occ;

        float rim = pow(max(dot(nor,normalize(vec3(-0.5,0.5,-0.8))),0.0),2.0);
        illumination += vec3(1.0,0.66,0.32)*rim*0.42;
        float specular = ks*pow(max(dot(nor,hal),0.0),se)*sha*(0.12+0.22*pow(fre,5.0));
        vec3 sheen = vec3(1.0,0.88,0.72)*specular;
        if(tm.y>3.5 && tm.y<4.5) sheen += vec3(0.13,0.073,0.034)*rim*occ;
        if(tm.y>2.5 && tm.y<3.5)
        {
            // Broad grazing fabric sheen follows the same warm window as the key.
            sheen += vec3(0.16,0.14,0.105)*pow(fre,2.3)*occ*(0.35+0.65*max(ndl,0.0));
        }
        col = col*illumination + sheen;
        // Gentle warm transmission at the thin edges of the skin.
        col += vec3(0.13,0.028,0.012)*sss*pow(fre,3.0)*(0.4+0.6*sha);
    }
        
    return col;
}

vec3 portraitTonemap(in vec3 linearColor)
{
    // Compress highlights in linear light, then convert to display gamma.
    vec3 x = max(linearColor*PORTRAIT_EXPOSURE,vec3(0.0));
    vec3 mapped = clamp((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14),0.0,1.0);
    return pow(mapped,vec3(1.0/2.2));
}
