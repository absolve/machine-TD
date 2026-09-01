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
var dragStartCameraPos: Vector2 = Vector2.ZERO # 按下时相机世界坐标

func _unhandled_input(_event):
	if _event.is_action_pressed("zoom_in"):
		CameraZoom(maxZoom)
	elif _event.is_action_pressed("zoom_out"):
		CameraZoom(minZoom)

	# 最小缩放时禁止拖动；放大后再允许拖拽到视野边缘
	if _event is InputEventMouseButton and _event.is_action("click"):
		if _event.is_pressed():
			if zoom.is_equal_approx(minZoom):
				dragging = false
				return
			dragging = true
			dragStartMouse = _event.position
			dragStartCameraPos = global_position
		else:
			dragging = false
	elif _event is InputEventMouseMotion and dragging:
		var screenDelta = _event.position - dragStartMouse
		var world_delta = screenDelta / zoom
		var target_pos = dragStartCameraPos - world_delta
		global_position = clampCameraPosition(target_pos)
		offset = Vector2.ZERO

# 限制相机可拖动到的边界：只有放大后才允许平移到边缘
func clampCameraPosition(pos: Vector2) -> Vector2:
	if zoom.is_equal_approx(minZoom):
		return global_position
	
	var viewportSize = get_viewport().get_visible_rect().size
	var visibleSize = viewportSize / zoom
	var halfVisible = visibleSize * 0.5
	var max_x = maxf(0.0, halfVisible.x)
	var max_y = maxf(0.0, halfVisible.y)
	return Vector2(
		clampf(pos.x, -max_x, max_x),
		clampf(pos.y, -max_y, max_y)
	)

#相机缩放函数
func CameraZoom(value):
	var mouse_world_before = get_global_mouse_position()
	var current_pos = global_position
	
	zoom = clamp(lerp(zoom, value, zoomSpeed), minZoom, maxZoom)
	
	# 让缩放围绕当前鼠标位置展开，避免缩放后拖拽出现错位。
	var mouse_world_after = get_global_mouse_position()
	global_position = current_pos + (mouse_world_before - mouse_world_after)
	global_position = clampCameraPosition(global_position)
	offset = Vector2.ZERO
