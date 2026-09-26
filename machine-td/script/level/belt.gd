extends AnimatedSprite2D
## 传送带（一格 = 64×64）。
##
## 贴图动画见 sprite/tile/belt_frames.tres：**动画名就是方向**，两个字母表示
## 「入口边 → 出口边」（we = 西进东出），共 4 个直段 + 8 个拐角。
##
## 用法：把 scene/belt.tscn 拖进关卡，位置对齐到格子中心，再在检查器里选 animation。
## · 想让带子动起来：往对应动画里加帧（节奏由 SpriteFrames 的 speed 决定）。
## · 想换皮带外观：把 sprite_frames 换成另一份 SpriteFrames（动画名沿用同一套方向名）即可。
##
## 流向提示不用滚动贴图，而是把每格的黄色箭头按明暗脉冲调制（见
## shader/belt_flow.gdshader）：每个实例在路线上有一个 route_phase（单位：格），
## 相邻格相位不同，合起来就是沿路线行进的明暗波 —— 箭头看起来在往前跑，
## 拐角自然拐过去，也不会出现"方向反了"或格子接缝。
## route_phase 由关卡生成脚本按路线弧长算好写进场景。

## 动画名写错 / 检查器里没选动画时的兜底方向
const DEFAULT_KEY := "we"

@export var snap_to_grid := true ## 进场景时把节点对齐到所在格子的中心
## 本格在整条路线上的位置（单位：格）。关卡生成脚本按弧长算好写进场景；
## 相邻格差 1 左右，明暗波就沿路线传下去了。
@export var route_phase := 0.0


func _ready() -> void:
	if snap_to_grid:
		_snap_to_cell()
	_ensure_animation()
	play() ## 帧动画得手动起跑（autoplay 留空，方向由 animation 决定）
	_apply_shader()


## 本实例覆盖的格子（中心坐标 → 格子索引）
func get_grid() -> Vector2i:
	var t: int = StageData.TileSize
	return Vector2i(floori(position.x / t), floori(position.y / t))


## 检查器里没选对动画时，回落到一个确实存在的动画，避免 play() 报错。
## 注意 has_animation() 是 SpriteFrames 上的方法，AnimatedSprite2D 没有。
func _ensure_animation() -> void:
	if sprite_frames == null or sprite_frames.has_animation(animation):
		return
	var names := sprite_frames.get_animation_names()
	if names.is_empty():
		return
	animation = DEFAULT_KEY if sprite_frames.has_animation(DEFAULT_KEY) else names[0]


func _apply_shader() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	# 同一个 .tscn 实例化出来的材质默认是共享的，各带各的相位就得先复制一份
	if not mat.resource_local_to_scene:
		mat = mat.duplicate() as ShaderMaterial
		material = mat
	mat.set_shader_parameter("route_phase", route_phase)


func _snap_to_cell() -> void:
	var t: int = StageData.TileSize
	position = Vector2(get_grid() * t) + Vector2(t, t) * 0.5
