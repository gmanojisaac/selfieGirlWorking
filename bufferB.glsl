// Depth of Field (depth defocus) on the background. It's a basic
// gather approach, where each pixel's neighborhood gets scanned
// and the Circle of Confusion computed for each one of those
// neighbor pixels. If the distance to the pixel is smaller than
// the Circle of Confusion, the current pixel gets a contribution
// from it with a weight that is inversely proportional to the
// area of the Circle of Confusion, to conserve energy.
//
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{	
    vec4 ref = texelFetch( iChannel0, ivec2(fragCoord),0);
    
    vec2 q = fragCoord/iResolution.xy;

    vec4 acc = vec4(0.0);
    const int N = 9;
	for( int j=-N; j<=N; j++ )
    for( int i=-N; i<=N; i++ )
    {
        vec2 off = vec2(float(i),float(j));
        
        vec4 tmp = texture( iChannel0, q + off/vec2(1280.0,720.0) ); 

        float coc = 0.01 + 9.0*(1.0-1.0/(1.0+0.01*abs(tmp.w)));
        
        if( dot(off,off) < coc*coc )
        {
            float w = 1.0/(coc*coc); 
            acc += vec4(tmp.xyz*w,w);
        }
    }
    vec3 col = acc.xyz / acc.w;

    fragColor = vec4(col,ref.w);
}
