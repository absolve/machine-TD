extends "res://script/tower.gd"

var sweep_angle := 0.0 # 雷达扫描角度
const EMP_COLOR := Color(0.2, 0.85, 1.0, 1.0) # 电磁主题色(青色)

func _process(delta):
	if selected:
		# 雷达扫描线匀速旋转
		sweep_angle = fmod(sweep_angle + delta * 1.8, TAU)
		queue_redraw()

func _draw():
	# 默认(未选中): 仅显示半透明范围圈
	if not selected:
		draw_circle(Vector2.ZERO, radarScope, Color(EMP_COLOR.r, EMP_COLOR.g, EMP_COLOR.b, 0.1))
		draw_arc(Vector2.ZERO, radarScope, 0, TAU, 64, Color(EMP_COLOR.r, EMP_COLOR.g, EMP_COLOR.b, 0.4), 1.0)
		return
	# 选中: 显示完整雷达扫描效果
	# 范围填充(半透明)
	draw_circle(Vector2.ZERO, radarScope, Color(EMP_COLOR.r, EMP_COLOR.g, EMP_COLOR.b, 0.12))
	# 范围外圈
	draw_arc(Vector2.ZERO, radarScope, 0, TAU, 64, Color(EMP_COLOR.r, EMP_COLOR.g, EMP_COLOR.b, 0.8), 2.0)
	# 同心环: 突出"减速波纹"效果
	for i in range(1, 4):
		var r = radarScope * (i / 4.0)
		draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(EMP_COLOR.r, EMP_COLOR.g, EMP_COLOR.b, 0.2), 1.0)
	# 雷达扫描扇形(渐变拖尾)
	var segments := 24
	var tail_span := PI / 3 # 拖尾跨度60度
	for s in range(segments):
		var t = float(s) / segments
		var a = sweep_angle - tail_span * t
		var alpha = (1.0 - t) * 0.5
		var next_a = sweep_angle - tail_span * (float(s + 1) / segments)
		var p1 = Vector2(cos(a), sin(a)) * radarScope
		var p2 = Vector2(cos(next_a), sin(next_a)) * radarScope
		draw_polygon(
			PackedVector2Array([Vector2.ZERO, p1, p2]),
			PackedColorArray([Color(EMP_COLOR.r, EMP_COLOR.g, EMP_COLOR.b, alpha),
				Color(EMP_COLOR.r, EMP_COLOR.g, EMP_COLOR.b, alpha),
				Color(EMP_COLOR.r, EMP_COLOR.g, EMP_COLOR.b, 0.0)])
		)
	# 扫描线主线
	draw_line(Vector2.ZERO, Vector2(cos(sweep_angle), sin(sweep_angle)) * radarScope,
		Color(EMP_COLOR.r, EMP_COLOR.g, EMP_COLOR.b, 1.0), 2.0)
