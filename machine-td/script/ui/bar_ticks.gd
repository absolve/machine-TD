extends Control
class_name BarTicks
## 血条分段刻度：在填充之上画等分竖线 + 1px 顶部亮边。
##
## 为什么单独一个 Control 自绘：刻度必须跟着条宽走，
## 摆 N 个 ColorRect 拼接的话，窗口一缩放就会错位（和 `boss_bar_ticks.gd` 同一个理由）。
## 挂在 `ProgressBar` 下、锚点铺满即可，`mouse_filter` 必须 IGNORE，别吃掉点击。

## 等分数。4 → 3 条刻线；给 0/1 就不画
@export var divisions: int = 4:
	set(value):
		divisions = value
		queue_redraw()

## 刻线颜色（默认近黑半透明，压在填充上像凹槽）
@export var tick_color: Color = Color(Palette.RIM, 0.5):
	set(value):
		tick_color = value
		queue_redraw()

@export var tick_width: float = 1.0

## 顶部 1px 亮边：让条子读成"有厚度的金属件"而不是一块色板
@export var top_glint: bool = true:
	set(value):
		top_glint = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if divisions > 1:
		for i in range(1, divisions):
			var x := roundf(size.x * float(i) / float(divisions))
			draw_rect(Rect2(x, 0.0, tick_width, size.y), tick_color)
	if top_glint:
		draw_rect(Rect2(0.0, 0.0, size.x, 1.0), Color(Palette.UI_000, 0.18))
