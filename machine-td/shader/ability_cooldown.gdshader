shader_type canvas_item;
// 技能冷却遮罩（顺时针扇形扫描）
//
// 适用节点：铺满技能槽的 ColorRect，材质用本着色器。
// progress = 剩余冷却比例：1 = 刚释放（几乎全盖），0 = 就绪（不覆盖）。
// 遮罩从 12 点方向开始顺时针覆盖，随着冷却推进逐渐收缩消失。

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cover_color : source_color = vec4(0.05, 0.06, 0.09, 0.78);
// 扫描边界的柔化宽度（按整圈归一化，0.03 ≈ 半径 36px 时约 7px）
uniform float softness : hint_range(0.001, 0.2) = 0.03;

const float TAU_F = 6.28318530717958647692;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float len = length(uv);
	// 12 点方向为 0，顺时针增大；圆心处 atan 无定义，直接取 0
	float ang = len > 0.0001 ? atan(uv.x, -uv.y) : 0.0;
	if (ang < 0.0) {
		ang += TAU_F;
	}
	float norm = ang / TAU_F;

	// 角度小于剩余比例的扇形保持遮盖
	float covered = 1.0 - smoothstep(progress - softness, progress + softness, norm);
	COLOR = vec4(cover_color.rgb, cover_color.a * covered);
}
