extends Sprite2D
## 传送带（一格 = 64×64）。原来铺在 TileMapLayer 里当瓦片，现改成独立场景，
## 这样每个实例都能挂材质，做流向动画。
##
## 贴图见 sprite/tile/belt_*.png，共 12 个方向：4 个直段 + 8 个拐角，
## 文件名两个字母表示「入口边 → 出口边」（we = 西进东出）。
##
## 流向提示不用滚动贴图，而是把每格的黄色箭头按明暗脉冲调制（见
## shader/belt_flow.gdshader）：每个实例在路线上有一个 route_phase（单位：格），
## 相邻格相位不同，合起来就是沿路线行进的明暗波 —— 箭头看起来在往前跑，
## 拐角自然拐过去，也不会出现"方向反了"或格子接缝。
##
## 用法：把 scene/belt.tscn 拖进关卡，位置对齐到格子中心，再把 texture 换成
## 需要的方向即可。route_phase 由关卡生成脚本按路线弧长算好写进场景。

## 边编号（仅用于描述方向，供校验/工具读取）
const EDGE_W := 0.0
const EDGE_E := 1.0
const EDGE_N := 2.0
const EDGE_S := 3.0

## 每种贴图的方向描述：flow = 行进方向（UV 空间：+x 向右，+y 向下），
## in_edge / out_edge = 入口边 / 出口边（0=西 1=东 2=北 3=南）。
## 动画本身不依赖这张表（波是沿路线传的），这里保留是为了能一眼看出
## 每个贴图应该贴在什么朝向的格子上，以及给校验脚本用。
const BELT := {
	# ---- 直段 ----
	"we": {"flow": Vector2(1, 0),  "in_edge": 0.0, "out_edge": 1.0},
	"ew": {"flow": Vector2(-1, 0), "in_edge": 1.0, "out_edge": 0.0},
	"ns": {"flow": Vector2(0, 1),  "in_edge": 2.0, "out_edge": 3.0},
	"sn": {"flow": Vector2(0, -1), "in_edge": 3.0, "out_edge": 2.0},
	# ---- 拐角：西进 ----
	"ws": {"flow": Vector2(0, 1),  "in_edge": 0.0, "out_edge": 3.0},
	"wn": {"flow": Vector2(0, -1), "in_edge": 0.0, "out_edge": 2.0},
	# ---- 拐角：东进 ----
	"es": {"flow": Vector2(0, 1),  "in_edge": 1.0, "out_edge": 3.0},
	"en": {"flow": Vector2(0, -1), "in_edge": 1.0, "out_edge": 2.0},
	# ---- 拐角：南进 ----
	"sw": {"flow": Vector2(-1, 0), "in_edge": 3.0, "out_edge": 0.0},
	"se": {"flow": Vector2(1, 0),  "in_edge": 3.0, "out_edge": 1.0},
	# ---- 拐角：北进 ----
	"nw": {"flow": Vector2(-1, 0), "in_edge": 2.0, "out_edge": 0.0},
	"ne": {"flow": Vector2(1, 0),  "in_edge": 2.0, "out_edge": 1.0},
}

@export var speed := 64.0 ## 保留：动画速度的换算基准（像素/秒）
@export var snap_to_grid := true ## 进场景时把节点对齐到所在格子的中心
## 本格在整条路线上的位置（单位：格）。关卡生成脚本按弧长算好写进场景；
## 相邻格差 1 左右，明暗波就沿路线传下去了。
@export var route_phase := 0.0


func _ready() -> void:
	if snap_to_grid:
		_snap_to_cell()
	_apply_shader()


## 本实例覆盖的格子（中心坐标 → 格子索引）
func get_grid() -> Vector2i:
	var t: int = StageData.TileSize
	return Vector2i(floori(position.x / t), floori(position.y / t))


## 贴图方向键（去掉 belt_ 前缀）；不是传送带贴图时回落到 "we"
func get_key() -> String:
	if texture == null:
		return "we"
	var k := texture.resource_path.get_file().get_basename().replace("belt_", "")
	return k if BELT.has(k) else "we"


## 整条带子的行进方向
func get_flow() -> Vector2:
	return BELT[get_key()]["flow"]


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
