extends Camera2D

# 缩放速度
@export var zoomSpeed: float = 0.15
# 最小缩放（最大视野，看更多东西）
@export var minZoom = Vector2(1, 1) # 最小缩放
# 最大缩放（放大很近）
@export var maxZoom = Vector2(1.5, 1.5) # 最大缩放
var zoomPosOffset = Vector2.ZERO # 缩放位置偏移

# 拖动相机状态
var dragging: bool = false
var dragStartMouse: Vector2 = Vector2.ZERO # 按下时鼠标屏幕坐标
var dragStartOffset: Vector2 = Vector2.ZERO # 按下时相机 offset

func _unhandled_input(_event):
	if _event.is_action_pressed("zoom_in"):
		CameraZoom(maxZoom)
	elif _event.is_action_pressed("zoom_out"):
		CameraZoom(minZoom)

	# 拖动相机：使用 click（左键）
	if _event is InputEventMouseButton and _event.is_action("click"):
		if _event.is_pressed():
			# zoom 为 1（最小缩放，已看全屏）时不允许拖动
			if zoom.is_equal_approx(minZoom):
				dragging = false
				return
			dragging = true
			dragStartMouse = _event.position
			dragStartOffset = offset
		else:
			dragging = false
	elif _event is InputEventMouseMotion and dragging:
		var screenDelta = _event.position - dragStartMouse
		# 不同 zoom 下，相同屏幕拖动量对应的世界坐标移动量不同：world_delta = screen_delta / zoom
		# zoom 越大，世界移动量越小（精细微调）；zoom=1 时 1:1
		var world_delta = screenDelta / zoom
		# 拖动方向：鼠标向右移动 → 内容跟随向右 → 相机向左移动 → offset 减小
		offset = clampOffset(dragStartOffset - world_delta)

# 限制 offset，使相机视野不会移出原本 zoom=1 可见的屏幕范围
func clampOffset(newOffset: Vector2) -> Vector2:
	var viewportSize = get_viewport().get_visible_rect().size
	# zoom 后相机可见的世界尺寸（zoom>1 时视野变小）
	var visibleSize = viewportSize / zoom
	# 可拖动范围：从中心向两侧最多 (viewport_size - visible_size) / 2
	# zoom=1 时 visible_size == viewport_size，max=0，即无法拖动
	var max_x = maxf(0.0, (viewportSize.x - visibleSize.x) / 2.0)
	var max_y = maxf(0.0, (viewportSize.y - visibleSize.y) / 2.0)
	return Vector2(
		clampf(newOffset.x, -max_x, max_x),
		clampf(newOffset.y, -max_y, max_y)
	)

#相机缩放函数
func CameraZoom(value):
	# 记录缩放前的鼠标位置
	zoomPosOffset = get_local_mouse_position()
	# 执行缩放
	zoom = clamp(lerp(zoom, value, zoomSpeed), minZoom, maxZoom)

	# 调整相机偏移，使缩放以光标为中心
	offset += zoomPosOffset - get_local_mouse_position()
	# 缩放改变了可见范围，重新限制 offset 避免越界
	offset = clampOffset(offset)
