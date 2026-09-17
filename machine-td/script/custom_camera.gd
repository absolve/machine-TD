extends Camera2D

## 缩放速度
#@export var zoomSpeed: float = 0.15
## 最小缩放（最大视野，看更多东西）
#@export var minZoom = Vector2(1, 1) # 最小缩放
## 最大缩放（放大很近）
#@export var maxZoom = Vector2(1.5, 1.5) # 最大缩放
#var zoomPosOffset = Vector2.ZERO # 缩放位置偏移
#
## 拖动相机状态
#var dragging: bool = false
#var dragStartMouse: Vector2 = Vector2.ZERO # 按下时鼠标屏幕坐标
#var dragStartCameraPos: Vector2 = Vector2.ZERO # 按下时相机世界坐标
#
#func _unhandled_input(_event):
	#if _event.is_action_pressed("zoom_in"):
		#CameraZoom(maxZoom)
	#elif _event.is_action_pressed("zoom_out"):
		#CameraZoom(minZoom)
#
	## 最小缩放时禁止拖动；放大后再允许拖拽到视野边缘
	#if _event is InputEventMouseButton and _event.is_action("click"):
		#if _event.is_pressed():
			#if zoom.is_equal_approx(minZoom):
				#dragging = false
				#return
			#dragging = true
			#dragStartMouse = _event.position
			#dragStartCameraPos = global_position
		#else:
			#dragging = false
	#elif _event is InputEventMouseMotion and dragging:
		#var screenDelta = _event.position - dragStartMouse
		#var world_delta = screenDelta / zoom
		#var target_pos = dragStartCameraPos - world_delta
		#global_position = clampCameraPosition(target_pos)
		#offset = Vector2.ZERO
#
## 限制相机可拖动到的边界：只有放大后才允许平移到边缘
#func clampCameraPosition(pos: Vector2) -> Vector2:
	#if zoom.is_equal_approx(minZoom):
		#return global_position
	#
	#var viewportSize = get_viewport().get_visible_rect().size
	#var visibleSize = viewportSize / zoom
	#var halfVisible = visibleSize * 0.5
	#var max_x = maxf(0.0, halfVisible.x)
	#var max_y = maxf(0.0, halfVisible.y)
	#return Vector2(
		#clampf(pos.x, -max_x, max_x),
		#clampf(pos.y, -max_y, max_y)
	#)
#
##相机缩放函数
#func CameraZoom(value):
	#var mouse_world_before = get_global_mouse_position()
	#var current_pos = global_position
	#
	#zoom = clamp(lerp(zoom, value, zoomSpeed), minZoom, maxZoom)
	#
	## 让缩放围绕当前鼠标位置展开，避免缩放后拖拽出现错位。
	#var mouse_world_after = get_global_mouse_position()
	#global_position = current_pos + (mouse_world_before - mouse_world_after)
	#global_position = clampCameraPosition(global_position)
	#offset = Vector2.ZERO


@export var map_rect: Rect2 = Rect2(0,0,2000,1200)
@export var zoom_speed:float = 0.10
@export var zoom_min:float = 1   # 最远缩小
@export var zoom_max:float = 3.0   # 最大放大
@export var drag_smooth:float = 8.0
@export var zoom_smooth:float = 8.0
@export var drag_threshold:float = 4.0 # 拖拽阈值，超过4像素才判定拖拽

var target_zoom:Vector2
var target_pos:Vector2
var is_dragging:bool = false
var drag_start_world:Vector2
var drag_start_cam_pos:Vector2
var drag_start_mouse:Vector2

enum AnchorMode {
	FIXED_TOP_LEFT = 0,
	DRAG_CENTER = 1
}

func _ready():
	target_zoom = zoom
	target_pos = global_position

func _process(delta):
	zoom = lerp(zoom, target_zoom, zoom_smooth * delta)
	global_position = lerp(global_position, target_pos, drag_smooth * delta)
	_clamp_camera_bounds()

func _input(event):
	# ===== 拖拽逻辑（带拖拽阈值） =====
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = false
				drag_start_mouse = get_global_mouse_position()
				drag_start_world = get_global_mouse_position()
				drag_start_cam_pos = target_pos
			else:
				is_dragging = false

		# ===== 滚轮缩放（鼠标中心点） =====
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_mouse(true)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_mouse(false)

	if event is InputEventMouseMotion:
		var mouse_world = get_global_mouse_position()
		if not is_dragging and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			# 判断是否超过拖拽阈值
			if drag_start_mouse.distance_to(mouse_world) > drag_threshold:
				is_dragging = true
		if is_dragging:
			var delta_world = drag_start_world - mouse_world
			target_pos = drag_start_cam_pos + delta_world

# 以鼠标位置为中心缩放
func _zoom_at_mouse(is_zoom_in:bool):
	var mouse_world = get_global_mouse_position()
	var old_zoom = target_zoom.x
	var delta = zoom_speed if is_zoom_in else -zoom_speed
	var new_zoom = clamp(old_zoom + delta, zoom_min, zoom_max)

	var factor = new_zoom / old_zoom
	target_pos = mouse_world - (mouse_world - target_pos) * factor
	target_zoom = Vector2(new_zoom, new_zoom)

# 【核心：兼容 anchor_mode 的边界计算】
func _clamp_camera_bounds():
	var vp_size = get_viewport().get_size()
	var view_size_world = vp_size / target_zoom.x

	# 根据 anchor_mode，计算相机节点位置到【屏幕世界中心点】的偏移
	var cam_to_screen_center:Vector2
	if anchor_mode == AnchorMode.FIXED_TOP_LEFT:
		# FIXED_TOP_LEFT：相机位置 = 屏幕左上角，屏幕中心 = cam_pos + 半视口
		cam_to_screen_center = view_size_world * 0.5
	else:
		# DRAG_CENTER 默认：相机位置就是屏幕中心点，偏移为0
		cam_to_screen_center = Vector2.ZERO

	# 屏幕世界中心点（target_pos 加上锚点偏移）
	var screen_center_world = target_pos + cam_to_screen_center

	# 可视矩形：屏幕世界中心点，向外扩展半视口
	var half_view = view_size_world / 2.0
	#var view_rect = Rect2(
		#screen_center_world - half_view,
		#view_size_world
	#)

	# 允许移动范围：保证 view_rect 完全落在 map_rect 内部
	var allow_min_x = map_rect.position.x + half_view.x
	var allow_max_x = map_rect.end.x - half_view.x
	var allow_min_y = map_rect.position.y + half_view.y
	var allow_max_y = map_rect.end.y - half_view.y

	# 地图比视口更小，锁死居中
	if map_rect.size.x <= view_size_world.x:
		allow_min_x = map_rect.get_center().x
		allow_max_x = map_rect.get_center().x
	if map_rect.size.y <= view_size_world.y:
		allow_min_y = map_rect.get_center().y
		allow_max_y = map_rect.get_center().y

	# 限制【屏幕中心点】，再反向算出 target_pos
	var clamped_screen_center = Vector2(
		clamp(screen_center_world.x, allow_min_x, allow_max_x),
		clamp(screen_center_world.y, allow_min_y, allow_max_y)
	)
	target_pos = clamped_screen_center - cam_to_screen_center
