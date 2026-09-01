shader_type canvas_item;

uniform float spark_frequency : hint_range(1.0, 20.0) = 7.0;
uniform float spark_size : hint_range(0.02, 0.35) = 0.12;
uniform float spark_speed : hint_range(0.1, 20.0) = 9.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec2 uv = UV;
    float pulse = 0.5 + 0.5 * sin(TIME * spark_speed + uv.y * 20.0);

    float x = fract(uv.x * spark_frequency + TIME * 0.7);
    float y = fract(uv.y * 6.0 + TIME * 0.9);
    float d = distance(vec2(x, y), vec2(0.5, 0.5));

    float dot = smoothstep(spark_size, 0.0, d);
    float band = step(0.15, uv.x) * step(uv.x, 0.9);
    float sparkle = dot * band * (0.5 + pulse * 0.8);

    COLOR = vec4(1.0, 1.0, 1.0, sparkle * alpha);
}
