// The photo is already display-ready: never apply the girl's exposure curve
// or vignette to it. Read level zero to retain the source image's fine detail.
vec3 photoBackground(vec2 fragCoord)
{
    vec2 size = vec2(textureSize(iChannel1,0));
    vec2 uv = fragCoord/iResolution.xy;
    float imageAspect = size.x/max(size.y,1.0);
    float screenAspect = iResolution.x/iResolution.y;
    // Centered cover crop: preserve proportions at portrait and landscape sizes.
    vec2 visible = vec2(min(screenAspect/imageAspect,1.0),
                        min(imageAspect/screenAspect,1.0));
    uv = (uv-0.5)*visible+0.5;
    return textureLod(iChannel1,uv,0.0).rgb;
}

vec3 sceneBackground(vec2 fragCoord, vec2 screenRay, vec3 ro, vec3 rd, float vignette)
{
#if PHOTO_BACKGROUND
    return photoBackground(fragCoord);
#else
    #if FIXED_BACKGROUND
        vec3 backgroundOrigin;
        // Starting front composition, independent of animation time.
        mat3 backgroundCamera = portraitCamera(0.1*ORBIT_SECONDS/6.28318530718,backgroundOrigin);
        vec3 backgroundRay = backgroundCamera*normalize(vec3(screenRay,2.70));
        vec3 color = portraitBackground(backgroundOrigin,backgroundRay);
    #else
        vec3 color = portraitBackground(ro,rd);
    #endif
    return portraitTonemap(color*vignette);
#endif
}
