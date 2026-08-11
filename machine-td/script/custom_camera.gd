extends Camera2D

# 缩放速度
@export var zoomSpeed: float = 0.15
# 最小缩放（最大视野，看更多东西）
@export var minZoom= Vector2(1, 1)  # 最小缩放
# 最大缩放（放大很近）
@export var maxZoom= Vector2(1.5, 1.5)  # 最大缩放
var zoomPosOffset =Vector2.ZERO  # 缩放位置偏移

func _unhandled_input(_event):
	if Input.is_action_just_pressed("zoom_in"):
		CameraZoom(maxZoom) 
	elif Input.is_action_just_pressed("zoom_out"):
		CameraZoom(minZoom) 
	

func CameraZoom(value):
	# 记录缩放前的鼠标位置
	zoomPosOffset=get_local_mouse_position()
	# 执行缩放
	zoom = clamp(lerp(zoom, value, zoomSpeed), minZoom, maxZoom)
	
	# 调整相机偏移，使缩放以光标为中心
	offset+=zoomPosOffset-get_local_mouse_position()
	
