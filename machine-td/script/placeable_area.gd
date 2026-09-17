extends Area2D
## 可放置区域（一格 = 64×64）。原来铺在 TileMapLayer 里当 floor_slot 瓦片，
## 现改成独立场景：子节点 slot 是塔位基座贴图，材质挂在它身上，方便加着色器动画。
##
## 玩法上：关卡里摆几个实例就代表哪几格能建塔 —— base_level.gd 会把
## "placeableArea" 组里的每个实例换算成网格坐标填进 allowArea。
## 放置方式：把 scene/placeable_area.tscn 拖进关卡，对齐到格子中心即可
## （运行时还会再对齐一次，见 snap_to_grid）。

@export var snap_to_grid := true ## 进场景时把节点对齐到所在格子的中心
@export var color := Color("d299b36b")
@export var isShow := false: ## 调试：把本格高亮出来（map.gd 取消选中时会关掉）
	set(value):
		isShow = value
		queue_redraw()


func _ready() -> void:
	if snap_to_grid:
		_snap_to_cell()


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
