extends Camera2D

## 自定义相机：滚轮缩放 + 按住左键拖动，**永远不越出关卡矩形**。
##
## 为什么必须夹死边界：敌人是从关卡边缘生成的，相机一旦能拖到关卡外面，
## 玩家就会直接看到"敌人凭空冒出来"。
##
## 本场景用 anchor_mode = FIXED_TOP_LEFT ——
## 也就是 global_position 表示可视区域的**左上角**，不是中心。
## 于是边界判定可以简化成一句：
##     左上角 ∈ [关卡左上角, 关卡右下角 - 视口世界尺寸]

## 关卡矩形（世界坐标）。所有关卡都是 1920x1080，需要时可在外面覆盖。
@export var map_rect: Rect2 = Rect2(0, 0, 1920, 1080)

@export var zoom_min: float = 1.0        # 最远（1 = 整关刚好铺满，不能再缩）
@export var zoom_max: float = 3.0        # 最近
@export var zoom_step: float = 0.12      # 每格滚轮的缩放比例
@export var zoom_smooth: float = 14.0
@export var drag_smooth: float = 20.0
@export var drag_threshold: float = 4.0  # 屏幕像素；超过才算拖拽，避免点塔时误拖

var target_zoom: float
var target_pos: Vector2

var _pressed := false                    # 左键是否按住
var _dragging := false
var _press_screen := Vector2.ZERO        # 按下时的屏幕坐标（只用来判定拖拽阈值）


func _ready() -> void:
	target_zoom = clampf(zoom.x, zoom_min, zoom_max)
	target_pos = _clamp_pos(global_position, target_zoom)
	_apply_now()


## 关卡加载后调用：复位成「整关刚好铺满」
func reset_view() -> void:
	target_zoom = clampf(1.0, zoom_min, zoom_max)
	target_pos = _clamp_pos(map_rect.position, target_zoom)
	_apply_now()


func _process(delta: float) -> void:
	# 先按目标缩放把目标位置夹住，缩放过渡期间目标也不会跑到界外
	target_pos = _clamp_pos(target_pos, target_zoom)
	zoom = zoom.lerp(Vector2(target_zoom, target_zoom), minf(1.0, zoom_smooth * delta))
	global_position = global_position.lerp(target_pos, minf(1.0, drag_smooth * delta))
	# 最后再用**当前**缩放夹一次实际位置，保证这一帧就不露出关卡外
	global_position = _clamp_pos(global_position, zoom.x)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = true
				_dragging = false
				_press_screen = event.position
			else:
				_pressed = false
				_dragging = false
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, zoom_step)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, -zoom_step)

	elif event is InputEventMouseMotion and _pressed:
		if not _dragging:
			# 超过阈值才判定为拖拽；起手这一帧的位移丢掉，避免刚开始拖就跳一下
			if _press_screen.distance_to(event.position) > drag_threshold:
				_dragging = true
			return
		# ★ 关键：用**每帧相对位移**（event.relative，屏幕像素）累积，再除以当前 zoom。
		#   踩过两次坑：
		#   1) 最早用「按下点 - 当前点」的**世界坐标**差 —— 那个值会跟着相机一起变，
		#      等价于 target = 2 * 起点 - 当前位置，每帧把相机往反方向甩，表现为抖动/偏移。
		#   2) 改成「按下点 - 当前点」的**屏幕**差除以 zoom 后，如果拖动时缩放动画还没收敛，
		#      zoom 每帧都在变，目标位置会被持续推着走（慢速漂移）。
		#   用 relative 累积对两者都免疫。
		target_pos = _clamp_pos(target_pos - event.relative / zoom, target_zoom)


# 以鼠标所在的世界点为中心缩放
func _zoom_at(screen_pos: Vector2, ratio: float) -> void:
	var old_zoom := target_zoom
	var new_zoom := clampf(old_zoom * (1.0 + ratio), zoom_min, zoom_max)
	if is_equal_approx(new_zoom, old_zoom):
		return
	# FIXED_TOP_LEFT 下：world = 相机左上角 + 屏幕坐标 / zoom
	var world_under_mouse := target_pos + screen_pos / old_zoom
	target_zoom = new_zoom
	target_pos = _clamp_pos(world_under_mouse - screen_pos / new_zoom, new_zoom)


# 把「可视区左上角」夹进关卡矩形。关卡比视口还小就贴住关卡左上角。
func _clamp_pos(pos: Vector2, z: float) -> Vector2:
	var view := get_viewport_rect().size / maxf(z, 0.001)
	var min_x := map_rect.position.x
	var max_x := maxf(min_x, map_rect.end.x - view.x)
	var min_y := map_rect.position.y
	var max_y := maxf(min_y, map_rect.end.y - view.y)
	return Vector2(clampf(pos.x, min_x, max_x), clampf(pos.y, min_y, max_y))


# 立刻生效（不做平滑）
func _apply_now() -> void:
	zoom = Vector2(target_zoom, target_zoom)
	global_position = target_pos
