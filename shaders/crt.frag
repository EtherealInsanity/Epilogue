#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform float uScanlineIntensity;
uniform float uCurvature;

out vec4 fragColor;

vec2 curve(vec2 uv) {
    uv = (uv - 0.5) * 2.0;
    uv *= 1.1;
    uv.x *= 1.0 + pow((abs(uv.y) / 5.0), 2.0) * uCurvature;
    uv.y *= 1.0 + pow((abs(uv.x) / 4.0), 2.0) * uCurvature;
    uv = (uv / 2.0) + 0.5;
    return uv;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    
    // Slight CRT barrel curvature
    if (uCurvature > 0.01) {
        uv = curve(uv);
    }
    
    // Vignette
    float vig = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    vig = clamp(pow(16.0 * vig, 0.25), 0.0, 1.0);
    
    // Raster scanlines
    float scanline = sin(uv.y * uResolution.y * 1.5) * 0.5 + 0.5;
    float scanFactor = 1.0 - (scanline * uScanlineIntensity * 0.3);
    
    // Border masking for barrel curvature
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        fragColor = vec4(0.0, 0.0, 0.0, (1.0 - (vig * scanFactor)) * 0.4);
    }
}
