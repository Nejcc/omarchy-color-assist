#version 300 es
// Color Assist: high contrast (Hyprland screen shader, GLSL ES 3.00).
// Linear contrast stretch around mid-gray, then a saturation boost around
// BT.709 luma. Tune CONTRAST / SATURATION here; 1.0 is identity.

precision mediump float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

const float CONTRAST = 1.6;
const float SATURATION = 1.3;

void main() {
    vec4 pix = texture(tex, v_texcoord);
    vec3 c = (pix.rgb - 0.5) * CONTRAST + 0.5;
    float y = dot(c, vec3(0.2126, 0.7152, 0.0722));
    c = mix(vec3(y), c, SATURATION);
    fragColor = vec4(clamp(c, 0.0, 1.0), pix.a);
}
