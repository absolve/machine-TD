extends Control
## Boss 血条上的**分段刻度**（25% / 50% / 75%）。
##
## 为什么单独一个 Control 做自绘，而不是摆 4 个 ProgressBar 拼起来：
##   拼 4 段要手动对齐宽度，窗口一缩放就会错位；画线只依赖自身尺寸，永远对齐。
##   而且线是画在 ProgressBar **上面**的（子节点晚于父节点绘制）——
##   如果直接写在血条根节点的 `_draw()` 里，会被 ProgressBar 盖住。

## 大 boss 进入二阶段后，50% 那条线换成橙红（和血条变色同步）
var phase2: bool = false

const COLOR_WEAK := Color(1.0, 1.0, 1.0, 0.45)
const COLOR_PHASE := Color(Palette.ALERT_500, 0.95)
const COLOR_PHASE2 := Palette.ALERT_HOT


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	# 三条刻度：0.5 那条画粗，就是"二阶段线"
	for f in [0.25, 0.5, 0.75]:
		var isMiddle: bool = is_equal_approx(float(f), 0.5)
		var x: float = size.x * float(f)
		var color: Color = COLOR_WEAK
		if isMiddle:
			color = COLOR_PHASE2 if phase2 else COLOR_PHASE
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), color, 3.0 if isMiddle else 1.5)
