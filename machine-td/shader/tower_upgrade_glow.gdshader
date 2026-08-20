shader_type canvas_item;

// 塔升级闪闪发光着色器
// 应用到塔的 Sprite2D/纹理上，升级时设置 enabled=1 并配合 intensity 淡入淡出

uniform float enabled : hint_range(0.0, 1.0) = 0.0;            // 是否启用（0=关，1=开）
uniform float intensity : hint_range(0.0, 2.0) = 1.0;          // 发光强度（用于淡入淡出）
uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.3, 1.0); // 发光颜色，默认金色
uniform float flash_speed : hint_range(0.5, 10.0) = 4.0;       // 闪烁频率（次/秒）
uniform float flash_amount : hint_range(0.0, 1.0) = 0.6;       // 闪烁幅度（0=恒亮，1=全暗到全亮）
uniform float edge_glow : hint_range(0.0, 2.0) = 0.8;          // 边缘发光强度

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    // 未启用时直接输出原纹理，零开销
    if (enabled < 0.5) {
        COLOR = tex_color;
    }else{
		// 闪烁：sin 周期变化，flash_amount 控制变化幅度
    float flash = 0.5 + 0.5 * sin(TIME * flash_speed * 6.28318);
    flash = mix(1.0 - flash_amount, 1.0, flash);

    // 边缘检测：UV 距边缘越近越亮，用 smoothstep 让过渡平滑
    vec2 edge_dist = min(UV, vec2(1.0) - UV);
    float edge_factor = 1.0 - smoothstep(0.0, 0.15, min(edge_dist.x, edge_dist.y));

    // 综合发光强度 = 基础 + 边缘增强，乘以闪烁
    float glow_strength = intensity * flash * (0.5 + edge_factor * edge_glow);
    vec3 glow_rgb = glow_color.rgb * glow_strength;

    // 加法叠加到原纹理（让塔整体变亮，保留轮廓）
    vec3 final_rgb = tex_color.rgb + glow_rgb * tex_color.a;

    COLOR = vec4(final_rgb, tex_color.a);
	}

    
}
