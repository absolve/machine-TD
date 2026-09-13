shader_type canvas_item;
// 工厂背景（占位版）。
//
// 原来的实现是把一张近黑的贴图直接乘上去，整屏是暗的。这里改成把贴图当成"细节图案"
// 叠加在中性底上：
//   base_color  → 车间基色（取自参考资源包的金属灰 #8c9195，与清屏色一致）
//   pattern     → 由贴图亮度差产生的轻微斑驳，模拟水泥/涂装表面的不均匀
//   top_shade   → 顶部轻微压暗，保留原来的纵向层次感
//
// 真正的工厂美术做出来后，直接替换本文件或换成美术资源即可，接口不用改。

uniform float speed = 0.1;
uniform vec4 base_color : source_color = vec4(0.54901963, 0.5686275, 0.58431375, 1.0);
uniform float pattern_strength : hint_range(0.0, 0.5) = 0.06;
uniform float top_shade : hint_range(0.0, 0.5) = 0.05;

varying float base_y;

void vertex() {
	base_y = UV.y;
	UV.y += speed * TIME;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	// 只取"相对中灰的偏差"作为图案，贴图本身明暗不影响整体亮度
	float detail = (lum - 0.5) * 2.0;
	vec3 col = base_color.rgb + detail * pattern_strength;
	col *= mix(1.0 - top_shade, 1.0, base_y);
	COLOR = vec4(col, 1.0);
}
