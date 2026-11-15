extends Control
## 四角角铁覆盖层（矢量）。比 `panel_brackets.gd` 更"通用"：
## 可以画在任意 Control 上，臂长/线宽/内缩/切角全可调。
##
## `fit_viewport = true` 时会自己铺满视口 —— 欢迎页的 `Ui` 根节点只有 40×40
## （子节点靠显式 offset 摆放、Control 默认不裁剪），所以全屏框不能依赖 anchors。

@export var fit_viewport: bool = false:
	set(value):
		fit_viewport = value
		_apply_fit()

@export var accent: Color = Color(Palette.UI_400, 0.22):
	set(value):
		accent = value
		queue_redraw()

## 臂长（像素）
@export var arm: float = 64.0:
	set(value):
		arm = value
		queue_redraw()

@export var thickness: float = 2.0:
	set(value):
		thickness = value
		queue_redraw()

## 内角切角，读成折角钢片而不是圆角
@export var chamfer: float = 8.0:
	set(value):
		chamfer = value
		queue_redraw()

## 离 Control 边缘的内缩
@export var inset: float = 8.0:
	set(value):
		inset = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	if fit_viewport:
		get_viewport().size_changed.connect(_apply_fit)
	_apply_fit()
	queue_redraw()


func _apply_fit() -> void:
	if not fit_viewport or not is_inside_tree():
		return
	position = Vector2.ZERO
	size = get_viewport_rect().size
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= inset * 2.0 or h <= inset * 2.0:
		return
	var a := minf(arm, minf(w, h) * 0.5 - inset)
	_corner(Vector2(inset, inset), Vector2(1.0, 1.0), a)
	_corner(Vector2(w - inset, inset), Vector2(-1.0, 1.0), a)
	_corner(Vector2(inset, h - inset), Vector2(1.0, -1.0), a)
	_corner(Vector2(w - inset, h - inset), Vector2(-1.0, -1.0), a)


func _corner(origin: Vector2, sign: Vector2, a: float) -> void:
	var pts := PackedVector2Array([
		origin,
		origin + Vector2(a * sign.x, 0.0),
		origin + Vector2(a * sign.x, thickness * sign.y),
		origin + Vector2((thickness + chamfer) * sign.x, thickness * sign.y),
		origin + Vector2(thickness * sign.x, (thickness + chamfer) * sign.y),
		origin + Vector2(thickness * sign.x, a * sign.y),
		origin + Vector2(0.0, a * sign.y),
	])
	draw_colored_polygon(pts, accent)
