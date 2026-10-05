shader_type canvas_item;
// 成就图标：未解锁时置灰压暗，解锁后原色显示
// 两个参数都由 achievement_panel.gd 按解锁状态设置，所以只需要两个共享材质实例。

uniform float desaturate : hint_range(0.0, 1.0) = 0.0; // 去色程度
uniform float dim : hint_range(0.0, 1.0) = 1.0; // 亮度
uniform float icon_zoom : hint_range(1.0, 1.5) = 1.25;
uniform vec4 outline_color : source_color = vec4(1.0, 0.78, 0.2, 0.9);
uniform float outline_width : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec2 source_uv = (UV - vec2(0.5)) / icon_zoom + vec2(0.5);
	vec4 tex = texture(TEXTURE, source_uv);
	float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 rgb = mix(tex.rgb, vec3(gray), desaturate) * dim;
	vec2 texel = TEXTURE_PIXEL_SIZE * outline_width;
	float neighbor_alpha = max(
		max(texture(TEXTURE, source_uv + vec2(texel.x, 0.0)).a,
			texture(TEXTURE, source_uv - vec2(texel.x, 0.0)).a),
		max(texture(TEXTURE, source_uv + vec2(0.0, texel.y)).a,
			texture(TEXTURE, source_uv - vec2(0.0, texel.y)).a)
	);
	float outline_alpha = max(0.0, neighbor_alpha - tex.a) * outline_color.a;
	COLOR = vec4(mix(outline_color.rgb, rgb, tex.a), max(tex.a, outline_alpha));
}
