shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform vec3 deep_color : source_color = vec3(0.10, 0.34, 0.43);
uniform vec3 crest_color : source_color = vec3(0.25, 0.54, 0.60);
uniform float wave_height = 0.032;
varying vec3 water_position;
varying vec3 water_normal;
varying float falling;
varying float running;
varying float depth;
varying vec2 flow;

void vertex() {
    vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    falling = COLOR.r;
    running = COLOR.g;
    depth = COLOR.b;
    flow = UV2;
    // World coordinates keep adjacent chunks in phase. Only the free surface
    // and its side edges move; the simulation and collision data remain fixed.
    float wave = sin(p.x * 2.1 + p.z * 1.3 + TIME * 1.1)
               + sin(p.x * -1.2 + p.z * 2.8 - TIME * 0.8) * 0.5;
    VERTEX.y += (wave - 1.5) * wave_height * UV.y * (1.0 - falling);
    water_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    water_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    vec2 p = water_position.xz;
    float a = p.x * 7.0 + p.y * 4.0 + TIME * 0.7;
    float b = p.x * -4.0 + p.y * 9.0 - TIME * 0.9;
    float ripple = sin(a) * 0.6 + sin(b) * 0.4;
    float calm_crest = pow(0.5 + 0.5 * sin(a + sin(b) * 0.6), 7.0);
    float calm_lines = calm_crest * (1.0 - running) * (1.0 - falling);
    vec2 direction = flow / max(length(flow), 0.001);
    vec2 across_direction = vec2(-direction.y, direction.x);
    float along = dot(p, direction);
    float across = dot(p, across_direction);
    // Long irregular ribbons travel downhill; calm pools retain crossing ripples.
    float current_phase = along * 13.0 - TIME * 5.0 + sin(across * 9.0) * 0.6;
    float ribbon = sin(across * 18.0 + sin(along * 2.0 - TIME * 1.7) * 0.65);
    float current = sin(current_phase) * 0.45 + ribbon * 0.55;
    float moving_y = water_position.y * 8.0 + TIME * 7.0;
    float strands = sin(water_position.x * 16.0 + water_position.z * 19.0
                      + sin(moving_y * 0.35) * 0.8);
    float rush = sin(moving_y + strands * 1.5);
    float foam = pow(max(0.0, strands * rush), 5.0) * falling * 0.38;
    float pattern = mix(mix(ripple, current, running), rush * 0.5 + strands * 0.5, falling);
    vec3 n = water_normal;
    if (abs(n.y) > 0.5) {
        vec2 calm_normal = vec2(cos(a), cos(b)) * 0.13;
        vec2 current_normal = across_direction * cos(across * 18.0) * 0.10
                            + direction * cos(current_phase) * 0.045;
        vec2 slope = mix(calm_normal, current_normal, running);
        n = normalize(n + vec3(slope.x, 0.0, slope.y));
    } else {
        n = normalize(n + vec3(0.02 * strands, 0.045 * rush, 0.02 * strands));
    }
    NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
    if (!FRONT_FACING) { NORMAL = -NORMAL; }
    float fresnel = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
    ALBEDO = mix(deep_color, crest_color, clamp(0.38 + pattern * 0.14 + fresnel * 0.4, 0.0, 1.0));
    ALBEDO = mix(ALBEDO, vec3(0.65, 0.80, 0.81), foam + calm_lines * 0.26);
    ALPHA = clamp(0.49 + depth * 0.32 + fresnel * 0.18 + falling * 0.08 + foam * 0.2, 0.0, 0.85);
    ROUGHNESS = 0.3;
    SPECULAR = 0.25;
}
