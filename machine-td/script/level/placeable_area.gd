extends Area2D
## 可放置区域（一格 = 64×64）。原来铺在 TileMapLayer 里当 floor_slot 瓦片，
## 现改成独立场景：子节点 slot 是塔位基座，材质挂在它身上，方便加着色器动画。
##
## 玩法上：关卡里摆几个实例就代表哪几格能建塔 —— base_level.gd 会把
## "placeableArea" 组里的每个实例换算成网格坐标填进 allowArea。
##
## ── 白点 → 黄点的呼吸渐变 ──
## 走 shader/palette_swap.gdshader 的色槽 1：把贴图里的白点（#FFFFFF）
## 按 blend_1 从"还是白色"慢慢混到"金黄"（#FFC61A），再混回来，来回呼吸。
## 速度由 dot_cycle_sec 控制 —— 想让变化更慢就把它调大。

@onready var slot: AnimatedSprite2D = get_node_or_null("slot")

@export var snap_to_grid := true ## 进场景时把节点对齐到所在格子的中心
@export var color := Color("d299b36b")
@export var isShow := false: ## 调试：把本格高亮出来（map.gd 取消选中时会关掉）
	set(value):
		isShow = value
		queue_redraw()

## 白点变黄再变回来的一个完整来回要多久（秒）。★ 调大 = 变化更慢。
@export var dot_cycle_sec := 4.0
## 是否参与呼吸渐变
@export var dot_pulse := true


func _ready() -> void:
	if snap_to_grid:
		_snap_to_cell()
	_play_slot()
	set_process(dot_pulse)


func _process(_delta: float) -> void:
	if slot == null:
		return
	var mat := slot.material as ShaderMaterial
	if mat == null:
		return
	# 相位取自全局时钟 —— 每个格子各跑 _process，但用的是同一个时钟，
	# 所以整片区域**同步**呼吸。如果各自计时会出现相位不一致，看着很乱。
	var t := float(Time.get_ticks_msec()) * 0.001
	# cos 从 1 摆到 -1，映射到 0..1：0 = 纯白，1 = 纯黄
	var k := 0.5 - 0.5 * cos(TAU * t / maxf(dot_cycle_sec, 0.1))
	mat.set_shader_parameter("blend_1", k)


## 让某些格子（比如已被占用的）停在白色、不参与呼吸
func set_dot_pulse(on: bool) -> void:
	dot_pulse = on
	set_process(on)
	if not on and slot != null:
		var mat := slot.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("blend_1", 0.0)


## 帧动画不会自己跑（AnimatedSprite2D 的 autoplay 留空），这里替它起跑；
## 动画名对不上时静默跳过，避免 play() 报错刷屏
func _play_slot() -> void:
	if slot == null or slot.sprite_frames == null:
		return
	if slot.sprite_frames.has_animation(slot.animation):
		slot.play()


## 本实例覆盖的格子（中心坐标 → 格子索引）
func get_grid() -> Vector2i:
	var t: int = StageData.TileSize
	return Vector2i(floori(position.x / t), floori(position.y / t))


func _snap_to_cell() -> void:
	var t: int = StageData.TileSize
	position = Vector2(get_grid() * t) + Vector2(t, t) * 0.5


func _draw() -> void:
	if not isShow:
		return
	var t: float = float(StageData.TileSize)
	var rect := Rect2(-Vector2(t, t) * 0.5, Vector2(t, t))
	draw_rect(rect, color, true)
	draw_rect(rect, Color.SALMON, false, 2.0)
