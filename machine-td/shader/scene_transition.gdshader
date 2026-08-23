shader_type canvas_item;

// 过渡进度: 0->0.5 方块从底行翻转盖满, 0.5->1 从底行收缩消失
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// 覆盖颜色
uniform vec4 fade_color : source_color = vec4(0.08, 0.09, 0.12, 1.0);
// 网格行列数 (16x9 在 1920x1080 下每格为正方形)
uniform vec2 grid_size = vec2(16.0, 9.0);

// 每格随机微延迟, 让翻转错落
float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// 当前像素所属格子坐标 + 格内局部坐标(0~1)
	vec2 cell = floor(UV * grid_size);
	vec2 cell_uv = fract(UV * grid_size);

	float total_rows = grid_size.y;
	// row_norm: 0=顶行, 1=底行
	float row_norm = cell.y / max(total_rows - 1.0, 1.0);
	// 每格随机微延迟 (0.30+0.05+0.15=0.50, 确保 0.5 时全部盖满)
	float jitter = hash21(cell) * 0.05;

	float alpha = 0.0;
	vec3 color = fade_color.rgb;

	if (progress <= 0.5) {
		// ===== 翻转盖满 0 -> 0.5 =====
		// 底行(row_norm=1)先翻转, 逐行向上蔓延
		// 时序: 最晚的格子 0.30+0.15=0.45 完成, 0.45->0.5 保持完全覆盖
		float start = (1.0 - row_norm) * 0.30 + jitter;
		float dur = 0.15;
		float t = clamp((progress - start) / dur, 0.0, 1.0);

		// 翻转角度 0 -> PI/2 (平躺 -> 竖直)
		// sin 缓入: 起始慢(刚离地), 中段快(翻过中点), 末段平滑到位
		float angle = t * 1.5708;
		float scale_y = sin(angle);

		// 底部锚定: 方块从底边向上翻转展开
		float block_min_y = 1.0 - scale_y;
		if (cell_uv.y >= block_min_y) {
			alpha = 1.0;
			// 模拟翻转面法线变化: 倾斜时偏暗, 竖直时最亮
			color *= mix(0.35, 1.0, sin(angle));
		}
	} else {
		// ===== 收缩消失 0.5 -> 1.0 =====
		// 底行先收缩, 向上蔓延
		float p = (progress - 0.5) / 0.5;
		float start = (1.0 - row_norm) * 0.30 + jitter;
		float dur = 0.15;
		float t = clamp((p - start) / dur, 0.0, 1.0);
		// 底部锚定收缩 + 淡出
		float scale_y = 1.0 - t;
		float block_min_y = 1.0 - scale_y;
		if (cell_uv.y >= block_min_y) {
			alpha = 1.0 - t;
		}
	}

	COLOR = vec4(color, alpha);
}
