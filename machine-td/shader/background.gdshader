shader_type canvas_item;
// 主菜单 / 选关页的背景。
//
// 结构就是最初的样子：一张 128x128 的双色棋盘格贴图平铺，UV 沿 Y 轴不断滚动，
// 再乘一层"上暗下亮"的纵向明暗。
//
// 唯一改动是颜色。贴图本身是中性深灰（两块 64px 方格，平均约 #2E2E2E），
// 直接乘出来是灰的，和现在深蓝灰的车间地砖（#333C57）不搭，所以加一个 tint 把它挪到蓝灰。
//
// tint 的数值是**实测标定**出来的：引擎采样纹理会做色彩空间处理，贴图在着色器里拿到的值
// 比 Image.get_pixel() 读到要亮一倍多。得到"输出 ≈ 108 × tint × factor"的线性关系后反解。
// factor 顶部 = darkness（压暗）、底部 = bottom_gain（在原色基础上再亮一档）。

uniform float speed = 0.1;
uniform vec4 tint : source_color = vec4(0.516, 0.607, 0.879, 1.0);
uniform float darkness : hint_range(0.0, 1.0) = 0.8;
uniform float bottom_gain : hint_range(0.8, 1.5) = 1.12;

varying float base_y;

void vertex() {
	base_y = UV.y;          // 先保存原始的 Y 坐标（0~1）
	UV.y += speed * TIME;   // 再让采样坐标滚动，产生背景流动
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	// 顶部(base_y=0)压暗，底部(base_y=1)比原色更亮一档
	float factor = mix(darkness, bottom_gain, base_y);
	COLOR = vec4(tex_color.rgb * tint.rgb * factor, 1.0);
}
