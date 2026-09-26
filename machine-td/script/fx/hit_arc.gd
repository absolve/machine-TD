extends Node2D
## 电弧击中效果 —— **独立场景**。
##
## 从命中点向四周迸出一束抖动的电弧，边闪边淡，播完自毁。
## 特斯拉塔打到每个敌人时在敌人身上放一个；别的需要"电一下"的地方也能直接用。
##
## 为什么不做成粒子：电弧要的是"折线抖动"（每 0.035 秒重算一次路径），
## 粒子系统给不了这种形状 —— 用 _draw 逐段画线最直接，也最像闪电。

## 一圈迸出几道电弧
@export var arc_count := 5
## 每道电弧分几段（段越多越碎）
@export var arc_segments := 5
## 一共闪多久（秒）
@export var duration := 0.22
## 每帧重算路径的间隔 —— 越小闪得越急
@export var flicker_interval := 0.035
## 电弧长度范围
@export var length_min := 26.0
@export var length_max := 58.0
## 抖动幅度
@export var jitter := 9.0
## 颜色（青蓝，和特斯拉闪电链同一色系）
@export var arc_color := Color(0.45, 0.85, 1.0, 1.0)

var _left := 0.0
var _flick := 0.0
var _arcs: Array = []


func _ready() -> void:
	z_index = 8
	_left = duration
	_flick = 0.0
	_rebuild()
	set_process(true)


func _process(delta: float) -> void:
	_left -= delta
	_flick -= delta
	if _flick <= 0.0:
		# 重算路径 —— 这就是"电弧在抖"的来源
		_rebuild()
		_flick = maxf(flicker_interval, 0.01)
	queue_redraw()
	if _left <= 0.0:
		queue_free()


func _rebuild() -> void:
	_arcs.clear()
	for i in arc_count:
		var ang := TAU * float(i) / float(arc_count) + randf_range(-0.45, 0.45)
		var dir := Vector2.RIGHT.rotated(ang)
		var perp := Vector2(-dir.y, dir.x)
		var length := randf_range(length_min, length_max)
		var pts := PackedVector2Array()
		pts.append(Vector2.ZERO)
		for k in range(1, arc_segments):
			var f := float(k) / float(arc_segments)
			# 抖动随距离放大：根部贴近中心、末端更散，像真的放电
			pts.append(dir * length * f + perp * randf_range(-jitter, jitter) * f)
		pts.append(dir * length)
		_arcs.append(pts)


func _draw() -> void:
	var a := clampf(_left / maxf(duration, 0.01), 0.0, 1.0)
	for pts in _arcs:
		for i in range(pts.size() - 1):
			# 三层叠加：外圈粗而暗、中层彩、内芯白 —— 和特斯拉塔的闪电画法一致
			draw_line(pts[i], pts[i + 1], Color(arc_color.r, arc_color.g, arc_color.b, a * 0.75), 3.0, true)
			draw_line(pts[i], pts[i + 1], Color(arc_color.r, arc_color.g, arc_color.b, a * 0.95), 1.3, true)
			draw_line(pts[i], pts[i + 1], Color(1, 1, 1, a * 0.9), 0.7, true)
	# 命中点的一点白光
	draw_circle(Vector2.ZERO, 7.0 * a, Color(1, 1, 1, a * 0.6))
	draw_circle(Vector2.ZERO, 3.5 * a, Color(1, 1, 1, a * 0.9))
