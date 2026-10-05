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
@export var mapRect: Rect2 = Rect2(0, 0, 1920, 1080)

@export var zoomMin: float = 1.0 # 最远（1 = 整关刚好铺满，不能再缩）
@export var zoomMax: float = 3.0 # 最近
@export var zoomStep: float = 0.12 # 每格滚轮的缩放比例
@export var zoomSmooth: float = 14.0
@export var dragSmooth: float = 20.0
@export var dragThreshold: float = 4.0 # 屏幕像素；超过才算拖拽，避免点塔时误拖

## 2D 听者：AudioStreamPlayer2D 的左右声像 + 距离衰减都以它为原点。
## 挂在相机下当子节点，位置每帧同步到**可视区域中心**（见 _syncAudioListener）。
@onready var audioListener: AudioListener2D = $AudioListener2D

var targetZoom: float
var targetPos: Vector2

var _pressed: bool = false # 左键是否按住
var _dragging: bool = false
var _pressScreen: Vector2 = Vector2.ZERO # 按下时的屏幕坐标（只用来判定拖拽阈值）


func _ready() -> void:
	targetZoom = clampf(zoom.x, zoomMin, zoomMax)
	targetPos = _clampPos(global_position, targetZoom)
	_applyNow()
	# ⚠️ AudioListener2D 没有「启用」属性：光把它放进场景**不会**生效，
	#    必须 make_current() 才会被 Viewport 当成听者（场景里也写了 current = true 兜一手）。
	audioListener.make_current()
	_syncAudioListener()


## 关卡加载后调用：复位成「整关刚好铺满」
func resetView() -> void:
	targetZoom = clampf(1.0, zoomMin, zoomMax)
	targetPos = _clampPos(mapRect.position, targetZoom)
	_applyNow()


func _zoomAt(screen_pos: Vector2, ratio: float) -> void:
	var oldZoom: float = targetZoom
	var newZoom: float = clampf(oldZoom * (1.0 + ratio), zoomMin, zoomMax)
	if is_equal_approx(newZoom, oldZoom):
		return
	# FIXED_TOP_LEFT 下：world = 相机左上角 + 屏幕坐标 / zoom
	var worldUnderMouse: Vector2 = targetPos + screen_pos / oldZoom
	targetZoom = newZoom
	targetPos = _clampPos(worldUnderMouse - screen_pos / newZoom, newZoom)


# 把「可视区左上角」夹进关卡矩形。关卡比视口还小就贴住关卡左上角。
func _clampPos(pos: Vector2, z: float) -> Vector2:
	var view: Vector2 = get_viewport_rect().size / maxf(z, 0.001)
	var minX: float = mapRect.position.x
	var maxX: float = maxf(minX, mapRect.end.x - view.x)
	var minY: float = mapRect.position.y
	var maxY: float = maxf(minY, mapRect.end.y - view.y)
	return Vector2(clampf(pos.x, minX, maxX), clampf(pos.y, minY, maxY))


# 立刻生效（不做平滑）
func _applyNow() -> void:
	zoom = Vector2(targetZoom, targetZoom)
	global_position = targetPos


## 把听者放到「可视区域中心」。
## ⚠️ 不能让它待在相机节点的原点上 —— 本相机是 FIXED_TOP_LEFT（anchor_mode = 0），
##    节点位置只是可视区的**左上角**，听者留在那里会让声像整体歪向一边。
##    相机可以拖动/缩放，所以这里每帧同步（宁可多算一句，也不想在某个缩放档位下歪）。
func _syncAudioListener() -> void:
	audioListener.global_position = get_screen_center_position()


func _process(delta: float) -> void:
	# 先按目标缩放把目标位置夹住，缩放过渡期间目标也不会跑到界外
	targetPos = _clampPos(targetPos, targetZoom)
	zoom = zoom.lerp(Vector2(targetZoom, targetZoom), minf(1.0, zoomSmooth * delta))
	global_position = global_position.lerp(targetPos, minf(1.0, dragSmooth * delta))
	# 最后再用**当前**缩放夹一次实际位置，保证这一帧就不露出关卡外
	global_position = _clampPos(global_position, zoom.x)
	# 听者跟着可视区中心走（相机能拖能缩，不跟着走声像就错了）
	_syncAudioListener()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = true
				_dragging = false
				_pressScreen = event.position
			else:
				_pressed = false
				_dragging = false
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoomAt(event.position, zoomStep)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoomAt(event.position, -zoomStep)

	elif event is InputEventMouseMotion and _pressed:
		if not _dragging:
			# 超过阈值才判定为拖拽；起手这一帧的位移丢掉，避免刚开始拖就跳一下
			if _pressScreen.distance_to(event.position) > dragThreshold:
				_dragging = true
			return
		# ★ 关键：用**每帧相对位移**（event.relative，屏幕像素）累积，再除以当前 zoom。
		#   踩过两次坑：
		#   1) 最早用「按下点 - 当前点」的**世界坐标**差 —— 那个值会跟着相机一起变，
		#      等价于 target = 2 * 起点 - 当前位置，每帧把相机往反方向甩，表现为抖动/偏移。
		#   2) 改成「按下点 - 当前点」的**屏幕**差除以 zoom 后，如果拖动时缩放动画还没收敛，
		#      zoom 每帧都在变，目标位置会被持续推着走（慢速漂移）。
		#   用 relative 累积对两者都免疫。
		targetPos = _clampPos(targetPos - event.relative / zoom, targetZoom)


# 以鼠标所在的世界点为中心缩放
