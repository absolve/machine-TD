extends Sprite2D
## 传送带（一格 = 64×64）。原来铺在 TileMapLayer 里当瓦片，现改成独立场景，
## 这样每个实例都能挂材质，做流动等着色器动画。
##
## 贴图见 sprite/tile/belt_*.png，共 12 个方向：4 个直段 + 8 个拐角，
## 文件名两个字母表示「入口方向 → 出口方向」（we = 西进东出）。
##
## 用法：把 scene/belt.tscn 拖进关卡，位置对齐到某一格的中心（运行时还会自动
## 再对齐一次，见 snap_to_grid），然后在检查器里把 texture 换成需要的方向即可 ——
## 流动方向会自动从贴图文件名推出来。

## 贴图文件名 → UV 流动方向（+x 向右，+y 向下）
const FLOW_BY_TEXTURE := {
	# 直段
	"belt_we": Vector2(1, 0),
	"belt_ew": Vector2(-1, 0),
	"belt_ns": Vector2(0, 1),
	"belt_sn": Vector2(0, -1),
	# 拐角：取「出口方向」近似，想更贴曲线可以在材质的 flow 上手动微调
	"belt_ws": Vector2(0, 1),
	"belt_wn": Vector2(0, -1),
	"belt_es": Vector2(0, 1),
	"belt_en": Vector2(0, -1),
	"belt_sw": Vector2(-1, 0),
	"belt_se": Vector2(1, 0),
	"belt_nw": Vector2(-1, 0),
	"belt_ne": Vector2(1, 0),
}

@export var speed := 64.0 ## 流动速度（像素/秒）
@export var snap_to_grid := true ## 进场景时把节点对齐到所在格子的中心


func _ready() -> void:
	if snap_to_grid:
		_snap_to_cell()
	_apply_flow()


## 本实例覆盖的格子（中心坐标 → 格子索引）
func get_grid() -> Vector2i:
	var t: int = StageData.TileSize
	return Vector2i(floori(position.x / t), floori(position.y / t))


## 用贴图文件名判断该往哪边流
func get_flow() -> Vector2:
	if texture == null:
		return FLOW_BY_TEXTURE["belt_we"]
	var key := texture.resource_path.get_file().get_basename()
	return FLOW_BY_TEXTURE.get(key, FLOW_BY_TEXTURE["belt_we"])


func _apply_flow() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	# 同一个 .tscn 实例化出来的材质默认是共享的，各带各的方向就得先复制一份
	if not mat.resource_local_to_scene:
		mat = mat.duplicate() as ShaderMaterial
		material = mat
	mat.set_shader_parameter("flow", get_flow())
	mat.set_shader_parameter("speed", speed)


func _snap_to_cell() -> void:
	var t: int = StageData.TileSize
	position = Vector2(get_grid() * t) + Vector2(t, t) * 0.5
