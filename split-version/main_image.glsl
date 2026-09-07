// INTERACTIVE in common.glsl selects AA and the camera-ray marching accuracy.
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
    vec2 q = (2.0*fragCoord-iResolution.xy)/iResolution.xy;
    float vignette = 1.0-0.13*smoothstep(0.35,1.6,dot(q,q));
    for(int m=ZERO; m<AA; m++)
    for(int n=ZERO; n<AA; n++)
    {
        vec2 offset = (vec2(float(m),float(n))+0.5)/float(AA)-0.5;
        vec2 p = (2.0*(fragCoord+offset)-iResolution.xy)/iResolution.y;
        // Preserve the entire head in narrow windows as well as landscape.
        float fit = max(1.0,0.95*iResolution.y/iResolution.x);
        vec3 rd = camera*normalize(vec3(p*fit,2.70));
        vec3 background = sceneBackground(fragCoord+offset,p*fit,ro,rd,vignette);
        float coverage;
        vec3 girl = renderGirl(ro,rd,20.0,vec3(0.0),time,coverage);
        // Composite each sample after tone mapping. Background pixels keep
        // their original colors, including along supersampled garment edges.
        total += mix(background,portraitTonemap(girl*vignette),coverage);
    }
    total /= float(AA*AA);
    fragColor = vec4(total,1.0);
}
