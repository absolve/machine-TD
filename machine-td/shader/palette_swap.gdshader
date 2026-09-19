shader_type canvas_item;

// ============================================================================
//  调色板替换（4 色槽）
//
//  用途：同一张贴图换出多套配色，不用为每个配色各画一份
//        （友方 / 敌方 / 不同阵营 / 不同关卡 / 未解锁置灰 ……）
//
//  ⚠️ 为什么用「容差」而不是相等判断：
//     shader 里颜色是 float，贴图采样、压缩、插值之后
//     你以为的 (0.16, 0.73, 0.40) 实际可能是 (0.160784, 0.733333, 0.400000)，
//     直接写 `==` 基本永远不成立。所以这里比的是「颜色距离」，
//     小于 tolerance 就算命中。
//
//  用法：
//     1. 给节点（Sprite2D / AnimatedSprite2D / TextureRect …）挂一个 ShaderMaterial
//     2. Shader 选 res://shader/palette_swap.gdshader
//     3. 勾上要用的槽（enabled_N），分别填「原色」和「新色」
//     4. 建议先把 tolerance 调到 0.02 试，命中不了再往上加
//
//  行内取色：填色时可以直接用取色器点贴图上要替换的那个颜色。
// ============================================================================

// 颜色距离小于它就判定为「同一个颜色」。
// 0.02 很严（几乎只认一模一样），0.08 比较宽松（能吃掉贴图压缩的误差）。
uniform float tolerance : hint_range(0.0, 1.0) = 0.06;

// 命中判定的软边。0 = 硬切换（像素画推荐）；
// 想让边缘平滑过渡就设成 0.02 ~ 0.1。
uniform float softness : hint_range(0.0, 0.5) = 0.0;

// 整体透明度（命中时用目标的 alpha 再乘一遍），一般不用动
uniform float alpha_scale : hint_range(0.0, 1.0) = 1.0;


// ---------------- 色槽 1 ----------------
uniform bool enabled_1 = false;
uniform vec4 source_1 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 target_1 : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// ---------------- 色槽 2 ----------------
uniform bool enabled_2 = false;
uniform vec4 source_2 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 target_2 : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// ---------------- 色槽 3 ----------------
uniform bool enabled_3 = false;
uniform vec4 source_3 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 target_3 : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// ---------------- 色槽 4 ----------------
uniform bool enabled_4 = false;
uniform vec4 source_4 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 target_4 : source_color = vec4(1.0, 1.0, 1.0, 1.0);


// 命中权重：orig 是贴图原色，src 是这个槽要替换的颜色。
// 注意判定永远拿 orig 比 —— 这样多个槽之间不会互相串色
// （否则 A→B、B→C 会连锁，把 A 一路换到 C）。
float hit_weight(vec3 orig, vec3 src) {
	float d = distance(orig, src);
	if (softness <= 0.0) {
		return d <= tolerance ? 1.0 : 0.0;
	}
	return 1.0 - smoothstep(tolerance, tolerance + softness, d);
}

// ⚠️ 关键坑：Godot 4 的 canvas_item 在 fragment() 入口时，
//    COLOR **已经等于「贴图色 × 顶点色(modulate)」，不是白色**。
//    所以结尾不能再写 `* COLOR` —— 那会把贴图原色又乘一遍，
//    结果变成 col × 原色（匹配上的地方看着就是「源色乘目标色」）。
//    正确做法：在 vertex() 里把顶点色单独存进 varying，fragment 里只乘它。
varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 base = tex.rgb;   // 贴图原色，所有槽都跟它比
	vec3 col = base;
	float alpha = tex.a;

	{
		float m = enabled_1 ? hit_weight(base, source_1.rgb) : 0.0;
		col = mix(col, target_1.rgb, m);
		alpha = mix(alpha, alpha * target_1.a, m);
	}
	{
		float m = enabled_2 ? hit_weight(base, source_2.rgb) : 0.0;
		col = mix(col, target_2.rgb, m);
		alpha = mix(alpha, alpha * target_2.a, m);
	}
	{
		float m = enabled_3 ? hit_weight(base, source_3.rgb) : 0.0;
		col = mix(col, target_3.rgb, m);
		alpha = mix(alpha, alpha * target_3.a, m);
	}
	{
		float m = enabled_4 ? hit_weight(base, source_4.rgb) : 0.0;
		col = mix(col, target_4.rgb, m);
		alpha = mix(alpha, alpha * target_4.a, m);
	}

	// 只乘顶点色（modulate），这样节点的 modulate / self_modulate 依然生效
	COLOR = vec4(col, alpha * alpha_scale) * v_modulate;
}
