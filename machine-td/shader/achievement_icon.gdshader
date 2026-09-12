shader_type canvas_item;
// 成就图标：未解锁时置灰压暗，解锁后原色显示
// 两个参数都由 achievement_panel.gd 按解锁状态设置，所以只需要两个共享材质实例。

uniform float desaturate : hint_range(0.0, 1.0) = 0.0; // 去色程度
uniform float dim : hint_range(0.0, 1.0) = 1.0; // 亮度

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 rgb = mix(tex.rgb, vec3(gray), desaturate) * dim;
	COLOR = vec4(rgb, tex.a);
}
