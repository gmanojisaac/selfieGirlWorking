// Analytic room surfaces and softly focused decor keep the atelier inexpensive.
// All coordinates are world-space so the room stays fixed throughout the orbit.
float studioBox(vec2 p, vec2 size)
{
    vec2 q = abs(p)-size;
    return length(max(q,0.0))+min(max(q.x,q.y),0.0);
}

float studioMask(float distance, float blur)
{
    return 1.0-smoothstep(-blur,blur,distance);
}

float studioGrain(vec2 p)
{
    float grain = noise1(iChannel0,vec3(p*vec2(7.0,0.38),9.0));
    float waves = sin(p.x*26.0+8.0*grain+1.8*sin(p.y*0.8));
    float fine = sin(p.x*95.0+5.0*grain);
    return 0.80+0.16*grain+0.045*waves+0.012*fine;
}

vec3 studioShelves(vec3 wall, vec2 p, float blur)
{
    float cabinet = studioMask(studioBox(p,vec2(1.62,3.40)),blur);
    vec3 wood = vec3(0.090,0.040,0.013)*studioGrain(p);
    vec3 inside = vec3(0.015,0.020,0.009);
    vec2 bay = vec2(p.x,mod(p.y+3.15,1.15)-0.575);
    float cavity = studioMask(studioBox(bay,vec2(1.44,0.48)),blur);
    wood = mix(wood,inside,cavity);
    float index = floor((p.x+1.42)/0.205);
    vec3 seed = hash3(uint(max(index+17.0*floor((p.y+3.15)/1.15)+220.0,0.0)));
    float height = 0.48+0.40*seed.x;
    vec2 book = vec2(mod(p.x+1.42,0.205)-0.1025,bay.y+0.45-height*0.5);
    book.x += 0.065*book.y*(seed.z-0.5);
    float spine = studioMask(studioBox(book,vec2(0.078,height*0.5)),blur*0.65)*cavity;
    vec3 bookColor = mix(vec3(0.045,0.068,0.025),vec3(0.18,0.065,0.018),seed.y);
    bookColor *= 0.65+0.55*smoothstep(-0.08,0.07,book.x);
    float gold = (1.0-smoothstep(0.012,0.034,abs(abs(book.y)-height*0.34)));
    bookColor = mix(bookColor,vec3(0.34,0.19,0.058),gold*0.65);
    wood = mix(wood,bookColor,spine);
    // Deep shelf recesses and a narrow brass edge, softened by depth of field.
    float rail = studioMask(abs(bay.y+0.51)-0.018,blur)*cavity;
    wood += vec3(0.075,0.035,0.008)*rail;
    wood *= 0.75+0.25*smoothstep(0.0,0.16,0.48-bay.y);
    return mix(wall,wood,cabinet);
}

vec3 studioWindow(vec3 wall, vec2 p, float blur)
{
    vec2 size = vec2(2.25,4.00);
    float edge = studioBox(p,size);
    float surround = studioMask(edge-0.16,blur);
    vec3 frame = vec3(0.14,0.068,0.021)*studioGrain(p);
    float panes = studioMask(edge+0.09,blur);
    float foliage = noise1(iChannel0,vec3(p*0.85,7.0));
    foliage = mix(foliage,noise1(iChannel0,vec3(p*2.7,11.0)),0.25);
    vec3 garden = mix(vec3(0.10,0.17,0.033),vec3(1.20,1.03,0.54),smoothstep(0.34,0.80,foliage));
    garden += vec3(0.45,0.34,0.17)*smoothstep(-1.3,2.0,p.y);
    for(int i=0;i<12;i++)
    {
        vec3 seed = hash3(uint(i+710));
        vec2 center = (seed.xy-0.5)*vec2(4.1,7.5);
        float glint = 1.0-smoothstep(0.10+0.08*seed.z,0.23+0.14*seed.z,length(p-center));
        garden += vec3(0.70,0.51,0.23)*glint;
    }
    // Window stiles, horizontal rails and softly glowing glass edges.
    vec2 grid = abs(mod(p+vec2(0.0,0.3),vec2(1.50,2.30))-vec2(0.75,1.15));
    float mullion = max(studioMask(grid.x-0.064,blur),studioMask(grid.y-0.072,blur));
    garden = mix(garden,frame*1.6,mullion);
    frame = mix(frame,garden,panes);
    wall = mix(wall,frame,surround);
    wall += vec3(0.055,0.031,0.010)*exp(-max(edge,0.0)*2.0)*(1.0-surround);
    float sill = studioMask(studioBox(p-vec2(0.0,-4.15),vec2(2.50,0.105)),blur);
    return mix(wall,vec3(0.18,0.088,0.028)*studioGrain(p.yx),sill);
}

vec3 studioWall(vec2 p, float face, float blur)
{
    float plaster = noise1(iChannel0,vec3(p*2.0,3.0));
    vec3 col = vec3(0.090,0.065,0.034)*(0.90+0.16*plaster);
    col *= 0.70+0.30*smoothstep(-6.2,1.0,p.y);
    col *= 0.66+0.34*exp(-dot((p-vec2(3.0,0.0))/vec2(6.0,8.0),(p-vec2(3.0,0.0))/vec2(6.0,8.0)));
    float panelling = 1.0-smoothstep(-3.8,-3.6,p.y);
    vec3 wood = vec3(0.066,0.031,0.012)*studioGrain(p);
    float panelEdge = abs(mod(p.x+0.7,1.4)-0.7);
    wood *= 0.63+0.37*smoothstep(0.025,0.09,panelEdge);
    col = mix(col,wood,panelling);
    col += vec3(0.037,0.021,0.008)*studioMask(abs(p.y+3.72)-0.026,blur);
    col = studioShelves(col,p-vec2(-5.0,-1.60),blur);
    // The wall opposite the starting camera contains the reference's tall window.
    if(face<0.5 || face>2.5) col = studioWindow(col,p-vec2(4.65,-0.45),blur);
    else col = studioShelves(col,p-vec2(4.45,-1.60),blur);

    // Framed tailoring sketch between shelving and the main window.
    vec2 art = p-vec2(-1.7,0.5);
    float frame = studioMask(studioBox(art,vec2(0.72,1.00)),blur);
    float paper = studioMask(studioBox(art,vec2(0.62,0.88)),blur);
    vec3 drawing = vec3(0.32,0.25,0.15);
    float outline = abs(abs(art.x)-(0.26+0.08*sin(art.y*4.0)));
    drawing *= 1.0-0.42*studioMask(outline-0.012,blur)*studioMask(abs(art.y)-0.70,blur);
    col = mix(col,mix(vec3(0.10,0.048,0.014),drawing,paper),frame);
    return col;
}

vec4 studioPlant(vec2 p, float blur)
{
    float pot = studioMask(studioBox(p-vec2(0.0,-0.22),vec2(0.30+0.08*p.y,0.31)),blur);
    vec3 col = vec3(0.13,0.085,0.033)*(0.65+0.35*smoothstep(-0.3,0.3,p.x));
    float alpha = pot;
    float stem = studioMask(abs(p.x-0.06*sin(p.y*2.0))-0.014,blur)*studioMask(abs(p.y-1.1)-1.1,blur);
    col = mix(col,vec3(0.055,0.065,0.016),stem);
    alpha = max(alpha,stem);
    for(int i=0;i<18;i++)
    {
        float fi = float(i);
        float side = mod(fi,2.0)*2.0-1.0;
        float y = 0.20+fi*0.126;
        float x = side*(0.18+0.35*sin(fi*2.31)*sin(fi*2.31))*(1.10-0.22*y);
        vec2 leaf = rot(p-vec2(x,y),side*(0.45+0.25*sin(fi)));
        float mask = studioMask((length(leaf/vec2(0.32,0.105))-1.0)*0.105,blur);
        vec3 green = mix(vec3(0.018,0.040,0.010),vec3(0.13,0.18,0.030),0.5+0.5*sin(fi*4.7));
        green += vec3(0.065,0.060,0.012)*smoothstep(-0.08,0.08,leaf.y);
        col = mix(col,green,mask);
        alpha = max(alpha,mask);
    }
    return vec4(col,alpha);
}

vec4 studioChair(vec2 p, float blur)
{
    float back = studioMask((length((p-vec2(0.0,0.40))/vec2(0.87,1.15))-1.0)*0.75,blur);
    float seat = studioMask(studioBox(p-vec2(0.0,-0.67),vec2(0.78,0.20)),blur);
    float arms = studioMask((length((vec2(abs(p.x),p.y)-vec2(0.82,-0.15))/vec2(0.22,0.55))-1.0)*0.22,blur);
    float leg = studioMask(studioBox(vec2(abs(p.x),p.y)-vec2(0.66,-1.25),vec2(0.064,0.44)),blur);
    float upholstery = max(back,max(seat,arms));
    float shade = 0.4+0.6*smoothstep(-0.85,0.85,p.x);
    vec3 leather = vec3(0.12,0.035,0.012)*shade;
    vec2 tuft = mod(p+vec2(0.10,0.05),vec2(0.38,0.42))-vec2(0.19,0.21);
    leather *= 1.0-0.58*exp(-dot(tuft,tuft)*180.0)*back;
    leather += vec3(0.052,0.021,0.008)*pow(max(0.0,1.0-abs(p.x)*0.8),6.0);
    return vec4(mix(vec3(0.050,0.023,0.008),leather,upholstery),max(upholstery,leg));
}

vec3 portraitBackground(in vec3 ro, in vec3 rd)
{
    vec3 extent = vec3(10.0,6.0,10.0);
    vec3 nearWall = vec3(1e5);
    if(abs(rd.x)>0.00001) nearWall.x = (sign(rd.x)*extent.x-ro.x)/rd.x;
    if(abs(rd.y)>0.00001) nearWall.y = ((rd.y>0.0 ? extent.y : -6.45)-ro.y)/rd.y;
    if(abs(rd.z)>0.00001) nearWall.z = (sign(rd.z)*extent.z-ro.z)/rd.z;
    float distance = min(nearWall.x,min(nearWall.y,nearWall.z));
    vec3 p = ro+rd*distance;
    float blur = 0.040+0.0025*distance;
    vec3 col;
    if(nearWall.y<min(nearWall.x,nearWall.z))
    {
        if(rd.y<0.0)
        {
            vec2 floorUV = p.xz;
            float plank = floor((floorUV.x+10.0)/1.05);
            float edge = abs(mod(floorUV.x+10.0,1.05)-0.525);
            float joint = abs(mod(floorUV.y+mod(plank,2.0)*1.85,3.7)-1.85);
            col = vec3(0.10,0.048,0.018)*studioGrain(floorUV*vec2(1.2,0.8));
            col *= 0.81+0.19*smoothstep(0.005,0.028,min(edge,joint));
            col *= 0.90+0.13*sin(plank*7.31);
            float sun = smoothstep(-3.0,5.0,p.x)*smoothstep(-8.0,-2.0,p.z);
            float bars = smoothstep(0.04,0.12,abs(mod(p.x+p.z*0.6,1.4)-0.7));
            col += vec3(0.24,0.15,0.055)*sun*bars;
            col *= 1.0-0.65*exp(-dot(p.xz/vec2(1.1,0.72),p.xz/vec2(1.1,0.72)));
        }
        else col = vec3(0.11,0.085,0.050)*(0.8+0.2*studioGrain(p.xz*0.4));
    }
    else if(nearWall.z<nearWall.x)
        col = studioWall(vec2(rd.z<0.0 ? p.x : -p.x,p.y),rd.z<0.0 ? 0.0 : 1.0,blur);
    else
        col = studioWall(vec2(rd.x>0.0 ? -p.z : p.z,p.y),rd.x>0.0 ? 2.0 : 3.0,blur);

    // Decor is behind the model and has its own camera parallax.
    if(abs(rd.z)>0.00001)
    {
        float decorT = (-6.5-ro.z)/rd.z;
        if(decorT>0.0 && decorT<distance)
        {
            vec2 decor = (ro+rd*decorT).xy;
            float soft = 0.020+0.002*decorT;
            vec4 plant = studioPlant(decor-vec2(5.25,-4.1),soft);
            col = mix(col,plant.rgb,plant.a);
            plant = studioPlant((decor-vec2(-4.9,-4.9))*0.86,soft);
            col = mix(col,plant.rgb,plant.a);
            vec4 chair = studioChair(decor-vec2(3.85,-4.60),soft);
            col = mix(col,chair.rgb,chair.a);
        }
    }
    return max(col,vec3(0.0));
}
