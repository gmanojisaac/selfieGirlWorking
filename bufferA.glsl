// Renders the background (trees, ground, river and bridge).
// The render uses a super basic implementation of Temporal
// Antialiasing (TAA) without color clipping or anything,
// but it's enough to stabilize aliasing. It also outputs
// the deph buffer into the alpha channel for the next pass
// ("Buffer B") to consume and do proper Depth Of Field.


// The ground - it's a simple box deformed by a few sine waves
//
float sdGround( in vec3 pos )
{
    pos -= vec3(120.0,-35.0,-700.0);
    pos.x += -150.0;
    pos.z += 30.0*sin(1.00*pos.x*0.016+0.0);
    pos.z += 10.0*sin(2.20*pos.x*0.016+1.0);
    pos.y += 20.0*sin(0.01*pos.x+2.0)*sin(0.01*pos.z+2.0);
    
    return sdBox(pos,vec3(1000.0,2.0,400.0))-10.0;
}

// The bridge. It's made of five boxes repeated forever
// with some mod() call, which are distorted with gentle
// sine waves so they don't look like perfectly geometrical. 
//
vec2 sdBridge( in vec3 pos )
{
    float issnow = 0.0;
    vec3 opos = pos;
    pos.x  += 50.0*sin(pos.z*0.01)+10.0;
    pos.xz += 0.05*sin(pos.yx+vec2(0,2));                
    vec3 sos = vec3(abs(pos.x),pos.yz);
    float h = -16.0;
    
    // floor
    vec3 ros = vec3(sos.xy,mod(sos.z+2.0,4.0)-2.0 )-vec3(0.0,h,0.0);
    float d = sdBox(ros,vec3(20.0,1.0,1.85));

    // thick bars
    ros = vec3(sos.xy,mod(sos.z+5.0,10.0)-5.0 )-vec3(20.0,h+5.0-0.4,0.0);
    float d2 = sdBox(ros,vec3(1.2,5.0,0.7)+0.1)-0.1;
    d = min(d,d2);
    
    #if 0
    {
    float id = floor((sos.z+5.0)/10.0);
    ros = vec3(sos.xy,mod(sos.z+5.0,10.0)-5.0 )-vec3(20.0,h-0.4,0.0);
	ros-=vec3(-1.5,1,0);
    ros.x -= ros.y;
    float ra = 0.5 + 0.5*sin(float(id)+4.0);
    float d2 = sdEllipsoid(ros,vec3(2.0,2.0,1.3)*ra);
    issnow = clamp( 0.5+0.5*(d-d2)/0.7, 0.0, 1.0 );
    d = smin(d,d2,0.7);
    }
    #endif

    // small bars
    ros = vec3(sos.xy,mod(sos.z+1.25,2.5)-1.25 )-vec3(20.0,h+5.0,0.0);
    d2 = sdBox(ros,vec3(0.2,5.0,0.2))-0.05;
    d = min(d,d2);
    
    // handle
    d2 = sdBox(sos-vec3(20.0,h+10.0,0.0),vec3(0.5,0.1,300.0))-0.4;
    d = min(d,d2);
    
    // foot bar
    d2 = sdBox(sos-vec3(20.0,h+2.4,0.0),vec3(0.7,0.1,300.0))-0.2;
    d = min(d,d2);
    
	return vec2(d,issnow);
}

// The trees are ultra basic and look really bad without
// defocus, but all I needed was something that looked like
// pine trees so the viewers would complete the picture in
// their heads. Only four trees are evaluated at any time,
// even though  there are inifinte many of them. Yet these
// four trees consume most of the rendering budget for the
// painting.
//
vec3 sdForest( in vec3 pos, float tmin )
{
    float shid = 0.0;
    
    const float per = 200.0;
    
    pos -= vec3(120.0,-16.0,-600.0);
        
    vec3 vos = pos/per;
    vec3 ip = floor(vos);
    
    bool hit = false;
    float d = tmin;
    float occ = 1.0;
    
    for( int j=0; j<=1; j++ )
    for( int i=0; i<=1; i++ )
    {
        vec2 of = vec2(i,j);
        ivec2 tid = ivec2(ip.xz + of );
        tid.y = min(tid.y,-0);
        
        uint treeId = uint(tid.y)*17u+uint(tid.x)*1231u;
        
        vec3 rf =  hash3( uint(treeId) )-0.5;
        
        vec3 ros = vec3( (float(tid.x)+rf.x)*per,
                         0.0,
                         (float(tid.y)+rf.y)*per );


        float hei = 1.0 + 0.2*sin( float(tid.x*115+tid.y*221) );
        hei *= (tid.y==0) ? 1.0 : 1.5;
          
        hei *= 275.0;

        float d2 = sdFakeRoundCone( pos-ros,hei,7.0,1.0);
        if( d2<d)
        {
            d = d2;
            hit = false;
        }
        
        if( d2-150.0>d ) continue;
        
        vec2 qos = pos.xz - ros.xz;
        float an = atan(qos.x,qos.y);
        float ra = length(qos);
        float vv = 0.3*sin(11.0*an) + 0.2*sin(28.0*an)+ 0.10*sin(53.0*an+4.0);

        
        // trick - only evalute 4 closest of the 10 cones
        int segid = int(floor(16.0*(pos.y-ros.y)/hei));
        for( uint k=ZEROU; k<4u; k++ )
        {
            uint rk = uint( min(max(segid+int(k),5),15) );
            
            float h = float(rk)/15.0;
            
            vec3 ran = hash3( treeId*24u+rk );
            
            h += 0.1*(1.0-h)*(ran.z-0.5) + 0.05*sin(1.0*an);

            ros.y = h*hei;
            
            float hh = 0.5 + 0.5*(1.0-h);
            float ww = 0.1 + 0.9*(1.0-h);
            hh *= 0.7+0.2*ran.x;
            ww *= 0.9+0.2*ran.y;
            hh *= 1.0+0.2*vv;
            
            vec2 rrr = vec2( ra, pos.y-ros.y );
            vec2 tmp = sdSegmentOri( rrr,vec2(120.0*ww,-100.0*hh));
            float d2 = tmp.x-mix(1.0,vv,tmp.y);
            if( d2<d )
            {
                hit = true;
                d = d2;
                shid = rf.z;
                occ = tmp.y * clamp(ra/100.0+h,0.0,1.0);
            }
        }
    }
    
    if( hit )
    {
        float dis = 0.5+0.5*fbm1(iChannel0,0.1*pos*vec3(1,0.3,1));
        d -= 8.0*dis-4.0;
        //occ = dis;
    }
    
	return vec3(d,shid,occ);
}


// The SDF of the landscape is made by combining ground, 
// bridge, river and trees. 
//
vec4 map( in vec3 pos, in float time, out float outMat, out vec3 uvw )
{
    pos.xz = rot(pos.xz,0.2);

    vec4 res = vec4(pos.y+36.0,0,0,0);    
    
    outMat = 1.0;
    uvw = pos;
    
    //-------
    {
    vec2 d2 = sdBridge(pos);
    if( d2.x<res.x )
    {
        res.xy = d2;
        outMat = 2.0;
    }
    }
    //-------
    float d = sdGround(pos);
    if( d<res.x )
    {
        res.x = d;
        outMat = 4.0;
    }
    //-------
    float bb = pos.z+450.0;
    if( bb<d )
    {
    vec3 d2 = sdForest(pos,d);
    if( d2.x<res.x )
    {
        res.x = d2.x;
        res.y = d2.y;
        res.z = d2.z;
        outMat = 3.0;
    }
    }
    
    return res;
}

// The landscape SDF again, but with extra high frequency
// modeling detail. While the previous one is used for
// raymarching and shadowing, this one is used for normal
// computation. This separation is conceptually equivalent
// to decoupling detail from base geometry with "normal
// maps", but done in 3D and with SDFs, which is way simpler
// and can be done correctly (something rarely seen in 3D
// engines) without any complexity.
//
float mapD( in vec3 pos, in float time )
{
    float matID; vec3 kk2;
    float d = map(pos,time,matID,kk2).x;
    
    if( matID<1.5 ) // water
    {
        float g = 0.5 + 0.5*fbm1f(iChannel2,0.02*pos.xz);
        g = g*g;
    	float f = 0.5 + 0.5*fbm1f(iChannel2,pos.xz);
        d -= g*12.0*(0.5+0.5*f*g*2.0);
    }
    else if( matID<2.5 ) // bridge
    {
    	d -= 0.07*(0.5+0.5*fbm1(iChannel0, pos*vec3(8,1,8) ));
    }
    else if( matID<4.5 ) // ground
    {
    	float dis = fbm1(iChannel0,0.1*pos);
    	d -= 3.0*dis;
    }
    
    return d;
}

// Computes the normal of the girl's surface (the gradient
// of the SDF). The implementation is weird because of the
// technicalities of the WebGL API that forces us to do
// some trick to prevent code unrolling. More info here:
//
// https://iquilezles.org/articles/normalsSDF
//
vec3 calcNormal( in vec3 pos, in float time, in float t )
{
    float eps = 0.001*t;
#if 0
    vec2 e = vec2(1.0,-1.0)*0.5773;
    return normalize( e.xyy*mapD( pos + e.xyy*eps,time ) + 
					  e.yyx*mapD( pos + e.yyx*eps,time ) + 
					  e.yxy*mapD( pos + e.yxy*eps,time ) + 
					  e.xxx*mapD( pos + e.xxx*eps,time ) );
#else
    vec4 n = vec4(0.0);
    for( int i=ZERO; i<4; i++ )
    {
        vec4 s = vec4(pos, 0.0);
        s[i] += eps;
        n[i] = mapD(s.xyz, time);
        //if( n.x+n.y+n.z+n.w>100.0 ) break;
    }
    return normalize(n.xyz-n.w);
#endif    
}

// Compute soft shadows for a given light, with a single ray
// insead of using montecarlo integration or shadowmap
// blurring. More info here:
//
// https://iquilezles.org/articles/rmshadows
//
float calcSoftshadow( in vec3 ro, in vec3 rd, in float mint, in float tmax, in float time, float k )
{
    float res = 1.0;
    float t = mint;
    
    // first things first - let's do a bounding volume test
    float tm = (480.0-ro.y)/rd.y; if( tm>0.0 ) tmax=min(tmax,tm);
    
    // raymarch and track penumbra
    for( int i=ZERO; i<128; i++ )
    {
        float kk; vec3 kk2;
		float h = map( ro + rd*t, time, kk, kk2 ).x;
        res = min( res, k*h/t );
        t += clamp( h, 0.05, 25.0 );
        if( res<0.002 || t>tmax ) break;
    }
    return max( res, 0.0 );
}

// Computes convexity for our landscape SDF, which can be
// used to approximate ambient occlusion. More info here:
//
// https://iquilezles.org/www/material/nvscene2008/rwwtt.pdf
//
float calcOcclusion( in vec3 pos, in vec3 nor, in float time, float sca, in vec2 px )
{
    float kk; vec3 kk2;
	float ao = 0.0;
    float off = textureLod(iChannel3,px/256.0,0.0).x;
    vec4 k = vec4(0.7012912,0.3941462,0.8294585,0.109841)+off;
    for( int i=ZERO; i<16; i++ )
    {
		k = fract(k + H4);
        vec3 ap = normalize(-1.0+2.0*k.xyz);
        float h = k.w*1.0*sca;
        ap = (nor+ap)*h;
        float d = map( pos+ap, time, kk, kk2 ).x;
        ao += max(0.0,h-d);
        if( ao>10000.0 ) break;
    }
	ao /= 16.0;
    return clamp( 1.0-ao*2.0/sca, 0.0, 1.0 );
}

// Computes the intersection point between our landscape SDF
// and a ray (coming form the camera in this case). It's a
// traditional and uncomplicated SDF raymarcher. More info:
//
// https://iquilezles.org/www/material/nvscene2008/rwwtt.pdf
//
vec2 intersect( in vec3 ro, in vec3 rd, in float time, out vec3 cma, out vec3 uvw )
{
    cma = vec3(0.0);
    uvw = vec3(0.0);
    float matID = -1.0;

    float tmax = 2500.0;
    float t = 15.0;
	// bounding volume test first    
    float tm = (480.0-ro.y)/rd.y; if( tm>0.0 ) tmax=min(tmax,tm);
    
    // raymarch
    for( int i=ZERO; i<1024; i++ )
    {
        vec3 pos = ro + t*rd;

        float tmp;
        vec4 h = map(pos,time,tmp,uvw);
        if( (h.x)<0.0002*t )
        {
            cma = h.yzw;
            matID = tmp;
            break;
        }
        t += h.x*0.8;
        if( t>tmax ) break;
    }

    return vec2(t,matID);
}

// Renders the landscape. It finds the ray-landscape
// intersection point, computes the normal at the
// intersection point, computes the ambient occlusion
// approximation, does per material setup (color,
// specularity, and paints some fake occlusion), and
// finally does the lighting computation.
//
vec4 renderBackground( in vec2 p, in vec3 ro, in vec3 rd, in float time, in vec2 px )
{
    // sky color
    vec3 col = vec3(0.45,0.75,1.1) + rd.y*0.5;
    vec3 fogcol = vec3(0.3,0.5,1.0)*0.25;
    col = mix( col, fogcol, exp2(-8.0*max(rd.y,0.0)) );
    
    // -------------------------------
    // find ray-landscape intersection
    // -------------------------------
    float tmin = 1e20;
    vec3 cma, uvw;
    vec2 tm = intersect( ro, rd, time, cma, uvw);

    // --------------------------
    // shading/lighting	
    // --------------------------
    if( tm.y>0.0 )
    {
        tmin = tm.x;
        
        vec3 pos = ro + tmin*rd;
        vec3 nor = calcNormal(pos, time, tmin);

        col = cma;

        float ks = 1.0;
        float se = 16.0;
        float focc = 1.0;
        float occs = 1.0;
        float snow = 1.0;
        
    	// --------------------------
        // materials
    	// --------------------------

        // water
        if( tm.y<1.5 )
        {
            col = vec3(0.1,0.2,0.3);
            occs = 20.0;
        }
        // bridge
        else if( tm.y<2.5 )
        {
            float f = 0.5 + 0.5*fbm1(iChannel0,pos*vec3(8,1,8));
            ks = f*8.0;
            se = 12.0;
            col = mix(vec3(0.40,0.22,0.15)*0.63,
                      vec3(0.35,0.07,0.02)*0.2,f);
            f = fbm1(iChannel0,pos*0.5);
            col *= 1.0 + 1.1*f*vec3(0.5,1.0,1.5);
          	col *= 1.0 + 0.2*cos(cma.y*23.0+vec3(0,0.2,0.5));
            
            float g = 0.5 + 0.5*fbm1(iChannel0,0.21*pos);
            g -= 0.8*nor.x*nor.x;
            snow *= smoothstep(0.2,0.6,g);
        }
        // forest
        else if( tm.y<3.5 )
        {
            col = vec3(0.2,0.1,0.02)*0.7;
            focc = cma.y*(0.7+0.3*nor.y);
            occs = 100.0;
        }
        // ground
        else if( tm.y<4.5 )
        {
            col = vec3(0.7,0.3,0.1)*0.12;
            float d = smoothstep(1.0,6.0,pos.y-(-36.0));
            col *= 0.2+0.8*d;
            occs = 100.0;
            snow = 1.0;
        }

        float fre = clamp(1.0+dot(nor,rd),0.0,1.0);
        float occ = focc*calcOcclusion( pos, nor, time, occs, px );

        snow *= smoothstep(0.25,0.3,nor.y);
        if( abs(tm.y-2.0)<0.5 )
        {
            snow = max(snow,clamp(1.0-occ*occ*3.5,0.0,1.0));
            snow = max(snow,cma.x);
        }

        col = mix( col, vec3(0.7,0.75,0.8)*0.6, snow);
		
		
    	// --------------------------
        // lighting
    	// --------------------------
        vec3 lin = vec3(0.0);

        vec3  lig = normalize(vec3(0.5,0.4,0.6));
        vec3  hal = normalize(lig-rd);
        float dif = clamp(dot(nor,lig), 0.0, 1.0 );
        //float sha = 0.0; if( dif>0.001 ) sha=calcSoftshadow( pos, lig, 0.001, 500.0, time, 8.0 );
        float sha = calcSoftshadow( pos, lig, 0.001, 500.0, time, 8.0 );
        dif *= sha;
        float spe = ks*pow(clamp(dot(nor,hal),0.0,1.0),se)*dif*(0.04+0.96*pow(clamp(1.0+dot(hal,rd),0.0,1.0),5.0));
        vec3  amb = occ*vec3(0.55+0.45*nor.y);

        lin += col*vec3(0.4,0.7,1.1)*amb;
        lin += col*1.4*vec3(2.3,1.5,1.1)*dif;
        lin += spe*2.0;
        lin += snow*vec3(0.21,0.35,0.7)*fre*fre*fre*(0.5+0.5*dif*amb)*focc;

        #if 1
        if( abs(tm.y-2.0)<0.5 )
        {
			float dif = max(0.2+0.8*dot(nor,vec3(-1,-0.3,0)),0.0);
			lin += col*vec3(0.58,0.29,0.14)*dif;
        }
		#endif
		col = lin;

        col = mix( col, vec3(0.3,0.5,1.0)*0.25, 1.0-exp2(-0.0003*tmin) );
    }

    // sun flow
    float glow = max(dot(rd,vec3(0.5,0.4,0.2)),0.0);
    glow *= glow;
    col += vec3(6.0,4.0,3.6)*glow*glow;

    return vec4(col,tmin);
}
    
// The main rendering entry point. Basically it does some
// setup or creating the ray that will explore the 3D
// scene in search of the landscape for each pixel, does
// the rendering of the landscape, and performs the
// Temporal Antialiasing before spiting out the color (in
// linear space, not gama) and the deph of the scene.
//
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // render
    vec2 o = hash3( uint(iFrame) ).xy - 0.5;
    vec2 p = (2.0*(fragCoord+o)-iResolution.xy)/iResolution.y;
        
    float time = 2.0 + iTime;
    
    // skip pixels behind girl
    #if 1
    if( length((p-vec2(-0.56, 0.2))/vec2(0.78,1.0))<0.85 ||
        length((p-vec2(-0.56,-0.4))/vec2(1.00,1.0))<0.73)
    {
        fragColor = vec4( 0.55,0.55,0.65,1e20 ); return;
    }
    #endif

    // camera movement	
    vec3 ro; float fl;
    mat3 ca = calcCamera( time, ro, fl );
    vec3 rd = ca * normalize( vec3((p-vec2(-0.52,0.12))/1.1,fl));

    vec4 tmp = renderBackground(p,ro,rd,time,fragCoord);
    vec3 col = tmp.xyz;

    //---------------------------------------------------------------
	// reproject from previous frame and average (cheap TAA, kind of)
    //---------------------------------------------------------------
    
    mat4 oldCam = mat4( textureLod(iChannel1,vec2(0.5,0.5)/iResolution.xy, 0.0),
                        textureLod(iChannel1,vec2(1.5,0.5)/iResolution.xy, 0.0),
                        textureLod(iChannel1,vec2(2.5,0.5)/iResolution.xy, 0.0),
                        0.0, 0.0, 0.0, 1.0 );
    bool oldStarted = textureLod(iChannel1,vec2(3.5,0.5)/iResolution.xy, 0.0).x>0.5;
    
    // world space
    vec4 wpos = vec4(ro + rd*tmp.w,1.0);
    // camera space
    vec3 cpos = (wpos*oldCam).xyz; // note inverse multiply
    // ndc space
    vec2 npos = fl * cpos.xy / cpos.z;
    // undo composition hack
    npos = npos*1.1+vec2(-0.52,0.12); 
    // screen space
    vec2 spos = 0.5 + 0.5*npos*vec2(iResolution.y/iResolution.x,1.0);
    // undo dither
    spos -= o/iResolution.xy;
	// raster space
    vec2 rpos = spos * iResolution.xy;
    
    if( rpos.y<1.0 && rpos.x<4.0 )
    {
    }
	else
    {
        vec3 ocol = textureLod( iChannel1, spos, 0.0 ).xyz;
    	if( !oldStarted ) ocol = col;
        col = mix( ocol, col, 0.1 );
    }

    //----------------------------------
    bool started = textureSize(iChannel0,0).x>=2 &&
                   textureSize(iChannel2,0).x>=2 &&
                   textureSize(iChannel3,0).x>=2;
                           
	if( fragCoord.y<1.0 && fragCoord.x<4.0 )
    {
        if( abs(fragCoord.x-3.5)<0.5 ) fragColor = vec4( started?1.0:0.0, 0.0, 0.0, 0.0 );
        if( abs(fragCoord.x-2.5)<0.5 ) fragColor = vec4( ca[2], -dot(ca[2],ro) );
        if( abs(fragCoord.x-1.5)<0.5 ) fragColor = vec4( ca[1], -dot(ca[1],ro) );
        if( abs(fragCoord.x-0.5)<0.5 ) fragColor = vec4( ca[0], -dot(ca[0],ro) );
    }
    else
    {
        fragColor = vec4( col, tmp.w );
    }
    
    if( !started ) fragColor = vec4(0.0);
}