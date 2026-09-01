shader_type canvas_item;

uniform float glow_width : hint_range(0.05, 0.8) = 0.25;
uniform float pulse_speed : hint_range(0.1, 20.0) = 6.0;
uniform float pulse_strength : hint_range(0.0, 2.0) = 1.2;
uniform float alpha : hint_range(0.0, 1.0) = 0.8;

void fragment() {
    float edge = 1.0 - smoothstep(glow_width, 1.0, UV.x);
    float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
    float glow = edge * (0.4 + pulse * pulse_strength);
    vec4 white = vec4(1.0, 1.0, 1.0, alpha * glow);
    COLOR = white;
}
