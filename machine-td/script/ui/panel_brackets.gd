extends PanelContainer
class_name PanelBrackets
## 面板四角角铁（矢量自绘）。
##
## 做法照抄 `level_card_frame.gd`，但直接挂在 `PanelContainer` 自身上：
## PanelContainer 节点自己的矩形**包含 content_margin**，所以角铁能贴着外框内侧画；
## 如果改成子节点，会被容器的边距挤到里面去。
##
## 为什么是"压暗"而不是像关卡卡那样用亮银：面板底 `#566C86` 已经是中灰，
## 再压一圈亮银会和 2px 亮边打架；用近黑半透明角铁才读成"钢板的折角"。
##
## 两种用法：
##   · 没有自己的脚本的面板 → 直接把本脚本挂到 PanelContainer 上；
##   · 已经带脚本的面板（塔/敌人详情）→ 在它们的 `_draw()` 里调 `PanelBrackets.paint(self)`。

## 角铁主色
@export var accent: Color = Color(Palette.UI_950, 0.55):
	set(value):
		accent = value
		queue_redraw()

## 臂长 = min(宽,高) × 该比例，再夹到 [arm_min, arm_max]
@export var arm_ratio: float = 0.09
@export var arm_min: float = 14.0
@export var arm_max: float = 30.0

## 角铁线宽
const THICK := 2.0
## 内角切角（读成折角钢片，不是圆角）
const CHAMFER := 5.0
## 离面板外缘的内缩（避开 10px 圆角）
const INSET := 6.0
const DEFAULT_ACCENT := Color(0.101960786, 0.10980392, 0.17254902, 0.55)  # Palette.UI_950 @ 0.55


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	paint(self, accent)


## 供"自带脚本的面板"调用：在自己的 _draw 里调用即可（记得 resized → queue_redraw）。
static func paint(ci: Control, accent: Color = DEFAULT_ACCENT) -> void:
	var w := ci.size.x
	var h := ci.size.y
	if w <= INSET * 2.0 or h <= INSET * 2.0:
		return
	var arm := clampf(minf(w, h) * 0.09, 14.0, 30.0)
	var x0 := INSET
	var y0 := INSET
	var x1 := w - INSET
	var y1 := h - INSET
	_corner(ci, Vector2(x0, y0), Vector2(1.0, 1.0), arm, accent)
	_corner(ci, Vector2(x1, y0), Vector2(-1.0, 1.0), arm, accent)
	_corner(ci, Vector2(x0, y1), Vector2(1.0, -1.0), arm, accent)
	_corner(ci, Vector2(x1, y1), Vector2(-1.0, -1.0), arm, accent)


static func _corner(ci: Control, origin: Vector2, sign: Vector2, arm: float, accent: Color) -> void:
	var pts := PackedVector2Array([
		origin,
		origin + Vector2(arm * sign.x, 0.0),
		origin + Vector2(arm * sign.x, THICK * sign.y),
		origin + Vector2((THICK + CHAMFER) * sign.x, THICK * sign.y),
		origin + Vector2(THICK * sign.x, (THICK + CHAMFER) * sign.y),
		origin + Vector2(THICK * sign.x, arm * sign.y),
		origin + Vector2(0.0, arm * sign.y),
	])
	ci.draw_colored_polygon(pts, accent)
