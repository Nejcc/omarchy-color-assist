#version 300 es
// Color Assist: Protanopia daltonization (Hyprland screen shader, GLSL ES 3.00).
//
// 1. RGB -> LMS cone space and the Protanopia dichromat projection, matrices from
//    O. Fidaner, P. Lin, N. Ozguven, "Analysis of Color Blindness" (Stanford,
//    2005), the same values daltonize.org and most daltonize tools use. They
//    follow the LMS projection model of Vienot, Brettel & Mollon, "Digital
//    video colourmaps for checking the legibility of displays by
//    dichromats", Color Research & Application 24(4), 1999.
// 2. error = original - simulated: the information this eye cannot see.
// 3. Shift the error into channels it can see (Fidaner et al. error matrix:
//    R' = 0, G' = 0.7 R + G, B' = 0.7 R + B) and add it back.

precision highp float; // LMS values reach ~65, keep full float precision
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 pix = texture(tex, v_texcoord);
    vec3 c = pix.rgb;

    vec3 lms = vec3(
        dot(c, vec3(17.8824, 43.5161, 4.11935)),
        dot(c, vec3(3.45565, 27.1554, 3.86714)),
        dot(c, vec3(0.0299566, 0.184309, 1.46709)));

    // Protanopia: L cones missing, rebuilt from M and S.
    lms = vec3(2.02344 * lms.y - 2.52581 * lms.z, lms.y, lms.z);

    vec3 sim = vec3(
        dot(lms, vec3(0.0809444479, -0.130504409, 0.116721066)),
        dot(lms, vec3(-0.0102485335, 0.0540193266, -0.113614708)),
        dot(lms, vec3(-0.000365296938, -0.00412161469, 0.693511405)));

    vec3 err = c - sim;
    vec3 shift = vec3(0.0, 0.7 * err.r + err.g, 0.7 * err.r + err.b);

    fragColor = vec4(clamp(c + shift, 0.0, 1.0), pix.a);
}
