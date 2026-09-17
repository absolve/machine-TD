shader_type canvas_item;
// 传送带流动动画。
//
// 皮带瓦片（sprite/tile/belt_*.png）横向筋周期 16px、人字形箭头周期 32px，
// 两者都整除 64px 一格，所以**跨格图案本来就是连续的**（见 feature_design.md v3.7）。
// 这里直接把 UV 沿 flow 偏移再 fract() 折回 [0,1) 采样：
//   - 不用开 texture repeat，也不会在格子边界出现接缝；
//   - 直段看起来就是皮带在跑，拐角件沿"出口方向"直线滚，算近似。
//
// 由 script/belt.gd 在 _ready() 里按贴图文件名设置 flow / speed。

uniform float speed = 64.0;          // 流动速度（像素/秒，按 64px 一格换算）
uniform vec2 flow = vec2(1.0, 0.0);  // 流动方向（UV 空间：+x 向右，+y 向下）
uniform vec2 tile_size = vec2(64.0, 64.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// 偏移量按「一格」取模：图案本身周期 16 / 32px，都能整除 64px 一格，
	// 所以滚过一格正好回到同一相位（看不出接缝），同时数值永远停在 [0,1) 里，
	// 挂机很久也不会因为浮点精度掉帧。
	float span = abs(flow.x) >= abs(flow.y) ? tile_size.x : tile_size.y;
	vec2 offset = flow * fract(speed * TIME / span);
	vec4 c = texture(TEXTURE, fract(UV + offset));
	COLOR = vec4(c.rgb * COLOR.rgb, c.a * COLOR.a * strength);
}
