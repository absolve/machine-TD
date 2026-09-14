shader_type canvas_item;
// 危险条纹带的滚动。
//
// 和背景那支是同一套思路（UV 每帧偏移），只是方向换成横向：
// 斜条横着流动，看起来就像一条在跑的警示胶带。
// 贴图本身是横向无缝的（宽度取条纹周期的整数倍），所以看不到接缝。

uniform float speed = 0.12;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = vec2(UV.x + TIME * speed, UV.y);
	vec4 c = texture(TEXTURE, uv);
	COLOR = vec4(c.rgb, c.a * alpha);
}
