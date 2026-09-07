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
    
    // Clip both ends against the same full-body bounds used for shadows.
    // Keep the existing 1.0 camera near distance; skip empty intervals.
    if( !clipCharacterBounds(ro,rd,t,tmax) ) return vec2(-1.0);

    // Use the step budget and hit accuracy selected in common.glsl.
    for( int i=0; i<RAYMARCH_STEPS; i++ )
    {
        vec3 pos = ro + t*rd;

        float tmp;
        vec4 h = map(pos,time,tmp,uvw);
        if( h.x<RAYMARCH_EPSILON )
        {
            cma = h.yzw;
            matID = tmp;
            break;
        }
        // The blended, distorted surfaces are not exact distance bounds.
        t += h.x*0.8;
        if( t>=tmax ) break;
    }

    return vec2(t,matID);
}
