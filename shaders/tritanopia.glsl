#version 300 es
// Color Assist: tritanopia daltonization (Hyprland screen shader, GLSL ES 3.00).
//
// 1. Simulate tritanopia with the RGB matrix (severity 1.0) from G. M.
//    Machado, M. M. Oliveira, L. A. F. Fernandes, "A Physiologically-based
//    Model for Simulation of Color Vision Deficiency", IEEE TVCG 15(6), 2009.
//    The Fidaner et al. tritan LMS row (S' = -0.396 L + 0.801 M) used by
//    daltonize.org pushes pure red to a blue of -3.0, so it is not used here.
// 2. error = original - simulated: the blue-yellow detail this eye loses.
// 3. Shift the error into red and green, which tritanopes still see. This
//    mirrors the Fidaner et al. red-green error matrix with the roles of the
//    lost and kept channels swapped: R' = R + 0.7 B, G' = G + 0.7 B, B' = 0.

precision highp float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 pix = texture(tex, v_texcoord);
    vec3 c = pix.rgb;

    vec3 sim = vec3(
        dot(c, vec3(1.255528, -0.076749, -0.178779)),
        dot(c, vec3(-0.078411, 0.930809, 0.147602)),
        dot(c, vec3(0.004733, 0.691367, 0.303900)));

    vec3 err = c - sim;
    vec3 shift = vec3(err.r + 0.7 * err.b, err.g + 0.7 * err.b, 0.0);

    fragColor = vec4(clamp(c + shift, 0.0, 1.0), pix.a);
}
