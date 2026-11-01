extends Control
class_name LevelCardLockIcon

## 未解锁卡片上的小挂锁图标（矢量）。
##
## 项目里没有现成的锁素材，写一个比去找图更省事 —— 形状也就三笔：
## 锁梁（半环）+ 锁体（方块）+ 锁孔（小圆点）。
## 配色走 art_style.md 的灰阶（压暗文字色 #9FB4C4）。

@export var color: Color = Color("9fb4c4"):
	set(value):
		color = value
		queue_redraw()

## 锁孔的颜色 = 锁牌底色（挖空用）
@export var holeColor: Color = Color("333c57"):
	set(value):
		holeColor = value
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var body_w := w * 0.68
	var body_h := h * 0.50
	var body_x := (w - body_w) * 0.5
	var body_y := h - body_h
	var stroke := maxf(2.0, w * 0.11)

	# 锁梁：从锁体上沿往上翻的半环
	var radius := body_w * 0.28
	draw_arc(Vector2(w * 0.5, body_y), radius, PI, TAU, 20, color, stroke, true)
	# 锁体
	draw_rect(Rect2(body_x, body_y, body_w, body_h), color)
	# 锁孔
	draw_circle(Vector2(w * 0.5, body_y + body_h * 0.42), body_w * 0.14, holeColor)
