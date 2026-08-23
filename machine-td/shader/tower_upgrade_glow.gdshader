shader_type canvas_item;

uniform bool enable_flash  = false; // 闪烁开关
uniform float base_brightness : hint_range(0.0, 2.0) =1;
uniform float flash_speed : hint_range(0.1, 100.0) = 50.0;// 闪烁速度，越大闪得越快
uniform float flash_amplitude : hint_range(0.0,1.5) = 1.0;// 闪烁振幅，越大越亮

// 描边
uniform float outline_thickness : hint_range(0.0,8.0) = 2.0;
uniform vec4 outline_color : source_color = vec4(1.0,1.0,1.0,1.0);

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    float final_bright = base_brightness;
    if(enable_flash){
       	float flash = step(0.0, sin(TIME * flash_speed));
        final_bright += flash * flash_amplitude;
    }

    vec4 result = tex;
    result.rgb *= final_bright;

    // 8方向描边采样
    vec2 px = (1.0 / TEXTURE_PIXEL_SIZE) * outline_thickness;
    float max_alpha = 0.0;
    max_alpha = max(max_alpha, texture(TEXTURE, UV + vec2(px.x,0)).a);
    max_alpha = max(max_alpha, texture(TEXTURE, UV - vec2(px.x,0)).a);
    max_alpha = max(max_alpha, texture(TEXTURE, UV + vec2(0,px.y)).a);
    max_alpha = max(max_alpha, texture(TEXTURE, UV - vec2(0,px.y)).a);
    max_alpha = max(max_alpha, texture(TEXTURE, UV + px).a);
    max_alpha = max(max_alpha, texture(TEXTURE, UV - px).a);
    max_alpha = max(max_alpha, texture(TEXTURE, UV + vec2(px.x,-px.y)).a);
    max_alpha = max(max_alpha, texture(TEXTURE, UV + vec2(-px.x,px.y)).a);

    float outline_alpha = max_alpha * (1.0 - tex.a);
    vec4 outline = outline_color;
    outline.rgb *= final_bright; // 描边跟随闪烁开关
    outline.a *= outline_alpha;

    COLOR = mix(result, outline, outline.a);
}
