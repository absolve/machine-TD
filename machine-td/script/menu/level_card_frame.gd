extends Control
class_name LevelCardFrame

## 关卡卡片外框：四角 L 形角铁 + 四边中点的短刻线。
##
## 为什么用矢量画而不是贴图：
##   · 角铁颜色要跟着状态走（黄=已通关 / 银=可玩 / 灰=未解锁 / 黄高光=悬停），
##     贴图换状态就得换资源，还得为每个状态各导一张；
##   · 卡片尺寸变了贴图会糊，矢量任何尺寸都是锐的；
##   · 悬停的"点亮"是渐变过渡，矢量改一个 Color 就能补间。
##
## 形状沿用原来的工厂风角铁（L 形 + 内角切角），保持既有辨识度。

## 角铁臂长
const BRACKET_LEN := 40.0
## 角铁粗细
const BRACKET_W := 7.0
## 内角切角（像钢板的折角）
const CHAMFER := 12.0
## 四边细框的内缩（离卡片边缘多远）
const EDGE_INSET := 3.0
## 四边细框的线宽
const EDGE_W := 1.0

## 角铁主色。改这个就换状态。
@export var accent: Color = Palette.UI_400:
	set(value):
		accent = value
		queue_redraw()

## 四边细框的透明度（比角铁淡一档，别跟角铁抢）
@export var edgeAlpha: float = 0.32:
	set(value):
		edgeAlpha = value
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	# 先铺一圈淡细框 —— 把卡片"切"出来，四角再压上亮角铁。
	# （只画四边中点的一小截刻线的话，在大片空底上会像误画的几道杠。）
	var edge := Color(accent.r, accent.g, accent.b, accent.a * edgeAlpha)
	draw_rect(Rect2(EDGE_INSET, EDGE_INSET, w - EDGE_INSET * 2.0, h - EDGE_INSET * 2.0),
		edge, false, EDGE_W)

	drawCorner(Vector2.ZERO, Vector2(1.0, 1.0))
	drawCorner(Vector2(w, 0.0), Vector2(-1.0, 1.0))
	drawCorner(Vector2(0.0, h), Vector2(1.0, -1.0))
	drawCorner(Vector2(w, h), Vector2(-1.0, -1.0))


## 画一个角的角铁。origin 是该角的位置，sign 是两个轴的朝向（用来镜像）。
func drawCorner(origin: Vector2, sign: Vector2) -> void:
	var pts := PackedVector2Array([
		origin,
		origin + Vector2(BRACKET_LEN * sign.x, 0.0),
		origin + Vector2(BRACKET_LEN * sign.x, BRACKET_W * sign.y),
		origin + Vector2((BRACKET_W + CHAMFER) * sign.x, BRACKET_W * sign.y),
		origin + Vector2(BRACKET_W * sign.x, (BRACKET_W + CHAMFER) * sign.y),
		origin + Vector2(BRACKET_W * sign.x, BRACKET_LEN * sign.y),
		origin + Vector2(0.0, BRACKET_LEN * sign.y),
	])
	draw_colored_polygon(pts, accent)
