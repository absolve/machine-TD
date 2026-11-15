extends GPUParticles2D
## 标题边缘的随机电火花。
##
## 不持续发射：用一个随机间隔的 Timer，每次在标题框边缘附近挑一个点，
## 把发射器挪过去再 restart() 冒一簇（one_shot），火花受重力往下掉。
## 加色混合（BLEND_MODE_ADD）让火花发亮，像电弧迸溅。

## 标题框矩形（welcome 坐标），火花沿它的上/左/右边缘出现
@export var frame_rect: Rect2 = Rect2(280, 37, 1360, 380)
@export var min_gap: float = 1.6
@export var max_gap: float = 4.0
@export var spark_texture: Texture2D = preload("res://sprite/spark_dot.png")

var _timer: Timer


func _ready() -> void:
	texture = spark_texture
	amount = 60
	lifetime = 0.9
	one_shot = true
	explosiveness = 1.0
	local_coords = false
	preprocess = 0.0

	var cim := CanvasItemMaterial.new()
	cim.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = cim

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 90.0
	mat.gravity = Vector3(0, 1000, 0)
	mat.initial_velocity_min = 140.0
	mat.initial_velocity_max = 460.0
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(34, 20, 1)
	mat.scale_min = 0.35
	mat.scale_max = 0.95
	mat.angular_velocity_min = -240.0
	mat.angular_velocity_max = 240.0
	mat.lifetime_randomness = 0.5
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 0.9, 0.4, 1), Color(0.85, 0.5, 0.05, 0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var gtex := GradientTexture1D.new()
	gtex.gradient = grad
	mat.color_ramp = gtex
	process_material = mat

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_burst)
	add_child(_timer)
	_timer.start(randf_range(min_gap, max_gap))


func _burst() -> void:
	position = _random_edge_point()
	restart()
	_timer.start(randf_range(min_gap, max_gap))


## 在标题框上/左/右边缘随机取一点（略向内偏，让火花贴边出现）
func _random_edge_point() -> Vector2:
	var l := frame_rect.position.x
	var t := frame_rect.position.y
	var r := frame_rect.end.x
	var b := frame_rect.end.y
	match randi() % 3:
		0:
			return Vector2(randf_range(l + 40, r - 40), t + 8)
		1:
			return Vector2(l + 8, randf_range(t + 40, b - 40))
		_:
			return Vector2(r - 8, randf_range(t + 40, b - 40))
	#return Vector2(l, t)
