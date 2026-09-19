shader_type canvas_item;
// 传送带的流向提示。
//
// 做法：**不动贴图**，只把每个格子里的黄色箭头（#FFC61A）按明暗脉冲调制。
// 每格在路线上有自己的位置 route_phase（单位：格），相邻格子的相位不同，
// 合起来就是一道沿路线行进的明暗波 —— 箭头看起来在"往前跑"，而且：
//   · 不采样 UV 偏移，所以没有「方向反了」的问题；
//   · 拐角件不用特殊处理，波是沿整条路线传播的，自然拐过去；
//   · 贴图本体完全不动，不会出现接缝。
//
// 之前试过滚动 UV，方向的正负号和拐角混合都很容易出错，这里换成脉冲。
//
// ⚠️ Godot 4 的 canvas_item 在 fragment() 入口时，COLOR 已经等于
//    「贴图采样 × 顶点色(modulate)」，不是白色 —— modulate 要用 varying 单独取。

uniform float route_phase = 0.0;   // 本格在路线上的位置（格），由 belt.gd 按关卡数据设置
uniform float wave_length = 4.0;   // 明暗波的长度（格）—— 越长，同时亮/同时暗的箭头越多
uniform float wave_speed = 0.35;   // 波速（格/秒）—— 越小越慢
uniform float dim = 0.45;          // 箭头暗态亮度系数（太暗会看不清箭头）
uniform float lit = 1.45;          // 箭头亮态亮度系数（>1 会往白里提亮，像发光）
uniform float strength : hint_range(0.0, 1.0) = 1.0;

// 箭头色（sprite/tile/belt_*.png 里的黄箭头）
const vec3 ARROW_COLOR = vec3(1.0, 0.776, 0.102);

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);

	// 用颜色距离识别箭头像素（贴图用最近邻采样，边缘会很干净）
	float d = distance(c.rgb, ARROW_COLOR);
	float is_arrow = 1.0 - smoothstep(0.10, 0.30, d);

	// 沿路线行进的明暗波
	float wave = 0.5 + 0.5 * sin((route_phase / wave_length - TIME * wave_speed) * TAU);
	float k = mix(1.0, mix(dim, lit, wave), is_arrow);

	COLOR = vec4(c.rgb * k, c.a * strength) * v_modulate;
}
