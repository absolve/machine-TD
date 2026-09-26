shader_type canvas_item;
// 敌人被击中的"变亮"反馈。
//
// 挂在 scene/enemy/enemy.tscn 的 base / turret 上，所有敌人共用 ——
// 派生敌人场景继承基场景，自动就有，不用一个个加。
//
// ⚠️ 是**整体提亮原色**，不是闪成白色 —— 用乘法，色相和明暗关系都保留，
//    只是那一瞬间"亮起来"。想要闪白的话把 brighten 拉高就行（会自然趋近白）。
//
// ⚠️ 两个 Godot 4 的坑（和 tower_upgrade_glow 踩的是同一对）：
//   1) fragment() 里 COLOR **进来时已经是 texture(TEXTURE,UV) * MODULATE**，
//      也就是已经乘过节点的 modulate / self_modulate 了。
//      所以**绝对不要整体赋值 COLOR = ...**，那会把 MODULATE 丢掉，
//      敌人的淡入淡出、受击染色就全废了。只能读进来、在它基础上改。
//   2) 不需要自己再乘一次 texture()，否则会暗一截。

// 提亮强度，0 = 原样，1 = 最亮。由 enemy.gd 用 Tween 从 1 补间到 0。
uniform float flash : hint_range(0.0, 1.0) = 0.0;
// flash=1 时的亮度倍率增量（0.8 表示最亮时是原色的 1.8 倍）
uniform float brighten : hint_range(0.0, 3.0) = 0.85;

void fragment() {
	vec4 col = COLOR;

	if (flash > 0.001) {
		// 乘法提亮：原色整体按倍数放大，色相不变
		col.rgb *= (1.0 + flash * brighten);
	}

	COLOR = col;
}