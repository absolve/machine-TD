extends "res://script/tower.gd"

const EMP_COLOR := Color(0.2, 0.85, 1.0, 1.0) # 电磁主题色(青色)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# 这里保留原有 EMP 逻辑
	pass

func _draw():
	# 未选中时保留原来的范围显示
	if not selected:
		draw_circle(Vector2.ZERO, radarScope, Color(EMP_COLOR.r, EMP_COLOR.g, EMP_COLOR.b, 0.1))
		draw_arc(Vector2.ZERO, radarScope, 0, TAU, 64, Color(EMP_COLOR.r, EMP_COLOR.g, EMP_COLOR.b, 0.4), 1.0)
		return
	# 选中时沿用父类的统一雷达扫描效果
	super._draw()
