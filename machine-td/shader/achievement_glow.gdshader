shader_type canvas_item;
// 成就图标：鼠标悬停时轮廓发光
//
// 用法：把本材质挂到图标控件上，脚本里把 glow 从 0 补间到 1。
//
// 原理：沿像素周围一圈采样贴图的 alpha，比较「自身 alpha」和「邻域 alpha」：
//   自身不透明 + 邻域开始透明  -> 落在轮廓内侧，画一圈描边
//   自身透明   + 邻域还有不透明 -> 落在轮廓外侧，画一圈辉光
// 所以不需要贴图自带描边通道，换任何带 alpha 的图标都能直接用。
//
// 注意：Godot 的 fragment() 里不能用 return 提前退出，所以下面用 if 包住整段计算。

uniform float glow : hint_range(0.0, 1.0) = 0.0; // 发光强度（由脚本驱动）
uniform vec4 glow_color : source_color = vec4(1.0, 0.84, 0.36, 1.0); // 金色描边
uniform float glow_width : hint_range(0.5, 8.0) = 2.5; // 采样半径（贴图像素）
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.4; // 整体强度

const int RING_SAMPLES = 12;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 rgb = tex.rgb;
	float alpha = tex.a;

	if (glow > 0.001) {
		// 环上双层采样：近邻给描边的锐度，远邻给辉光的扩散
		float near_ring = 0.0;
		float far_ring = 0.0;
		for (int i = 0; i < RING_SAMPLES; i++) {
			float ang = float(i) * 6.2831853 / float(RING_SAMPLES);
			vec2 dir = vec2(cos(ang), sin(ang));
			near_ring += texture(TEXTURE, UV + dir * TEXTURE_PIXEL_SIZE * glow_width).a;
			far_ring += texture(TEXTURE, UV + dir * TEXTURE_PIXEL_SIZE * glow_width * 2.4).a;
		}
		near_ring /= float(RING_SAMPLES);
		far_ring /= float(RING_SAMPLES);

		float k = glow * glow_intensity;
		// 两个因子互补，保证 alpha 过渡带（抗锯齿边缘）不会出现一圈暗缝
		float rim = tex.a * (1.0 - near_ring);
		float halo = (1.0 - tex.a) * mix(near_ring, far_ring, 0.6);

		rgb = mix(rgb, glow_color.rgb, clamp(rim * k * 1.5, 0.0, 1.0));
		rgb = mix(rgb, glow_color.rgb, clamp(halo * k * 1.8, 0.0, 1.0));
		alpha = clamp(max(tex.a, halo * glow * 1.5), 0.0, 1.0);
	}

	COLOR = vec4(rgb, alpha);
}
