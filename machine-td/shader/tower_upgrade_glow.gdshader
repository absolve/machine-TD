shader_type canvas_item;
// 防御塔升级 / 修理闪光
//
// 平时完全透明（enable_flash = false 时只是原样输出，零副作用），
// 升级时把 enable_flash 打开，塔身会呼吸式发亮 + 描一圈白边。
//
// ⚠️ 两个必须记住的 Godot 4 坑（这版就是踩了才改的）：
//
//  1) canvas_item 的 fragment() 里，COLOR **进来时已经是
//     texture(TEXTURE, UV) * MODULATE** —— 也就是已经乘过节点的
//     modulate / self_modulate 了。
//     所以：
//       · 不要再自己乘一次 texture()，否则会暗一大截；
//       · **绝对不要整体赋值 COLOR = ...**，那会把 MODULATE 丢掉，
//         节点的淡入淡出、受伤染色、透明度就全部失效了
//         （旧版写的 COLOR = mix(tex, outline, ...) 就是这个毛病）。
//     正确做法：读进 COLOR 保留它，只在它基础上改。
//
//  2) 描边的采样步长是 TEXTURE_PIXEL_SIZE * 像素数。
//     旧版写成 (1.0 / TEXTURE_PIXEL_SIZE) * thickness —— 那是
//     "整张贴图尺寸的倍数"，等于采样到贴图外面去了，描边永远不出现。

// 闪烁开关（升级/修理时由 tower.gd 打开）
uniform bool enable_flash = false;
// 基础亮度（1.0 = 原样）
uniform float base_brightness : hint_range(0.0, 2.0) = 1.0;
// 呼吸速度，越大闪得越快（建议 8~20，50 会变成频闪）
uniform float flash_speed : hint_range(0.1, 100.0) = 14.0;
// 呼吸振幅，越大越亮
uniform float flash_amplitude : hint_range(0.0, 1.5) = 0.8;
// 描边粗细（贴图像素）。**默认 0 = 关闭**。
// ⚠️ 塔的贴图是图集区域（AtlasTexture），TEXTURE_PIXEL_SIZE 拿到的是
//    **整张图集**的像素尺寸，UV 偏移会跨出 region 采到旁边的格子，
//    结果是大面积误判、糊成一团白（实测过）。
//    要用描边的话：给这张图单独出一份非图集的贴图，或者改成按 region 尺寸算步长。
uniform float outline_thickness : hint_range(0.0, 8.0) = 0.0;
// 描边颜色
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	// COLOR 进来已经含了贴图和节点 modulate，直接拿来用
	vec4 base_col = COLOR;
	float base_a = base_col.a;

	// 亮度 = 基础 + 呼吸。用 abs(sin) 让它是"脉冲"而不是"硬开关"，
	// 旧版用 step(sin) 只有 0/1 两态，看着像频闪灯。
	float bright = base_brightness;
	if (enable_flash) {
		bright += abs(sin(TIME * flash_speed)) * flash_amplitude;
	}
	base_col.rgb *= bright;

	// 描边：只往外扩，所以取"自己透明但邻居不透明"的那一圈
	float outline_a = 0.0;
	if (outline_thickness > 0.0) {
		vec2 d = TEXTURE_PIXEL_SIZE * outline_thickness;
		float max_a = 0.0;
		max_a = max(max_a, texture(TEXTURE, UV + vec2(d.x, 0.0)).a);
		max_a = max(max_a, texture(TEXTURE, UV - vec2(d.x, 0.0)).a);
		max_a = max(max_a, texture(TEXTURE, UV + vec2(0.0, d.y)).a);
		max_a = max(max_a, texture(TEXTURE, UV - vec2(0.0, d.y)).a);
		max_a = max(max_a, texture(TEXTURE, UV + d).a);
		max_a = max(max_a, texture(TEXTURE, UV - d).a);
		max_a = max(max_a, texture(TEXTURE, UV + vec2(d.x, -d.y)).a);
		max_a = max(max_a, texture(TEXTURE, UV + vec2(-d.x, d.y)).a);
		outline_a = max_a * (1.0 - base_a);
	}

	// 描边也跟随亮度，闪光时整圈一起亮
	vec3 rgb = mix(base_col.rgb, outline_color.rgb * bright, outline_a);
	// alpha 取两者较大的：塔身自己的 alpha 不能被描边改小，
	// 否则半透明淡出时塔身会跟着变淡（旧版就有这个连带问题）
	float out_a = max(base_a, outline_color.a * outline_a);

	COLOR = vec4(rgb, out_a);
}
