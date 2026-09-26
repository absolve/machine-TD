extends Node2D
## 地图装饰物的基类（排风扇 / 警示灯 / 蒸汽口 / 焊接火花 / 监控屏 …）。
##
## 所有装饰场景都是 scene/prop/prop_base.tscn 的**继承场景**：
## 基类提供结构（Node2D + 一个 AnimatedSprite2D），继承场景只覆盖
## anim 的 sprite_frames。要加新装饰，照着现有的复制一份、换图集即可。
##
## 装饰物**不参与玩法** —— 没有碰撞体、不挡路、不占建造格，只是让工厂看起来在运转。
## 摆放位置由关卡生成脚本挑「既不是路面、也不是可建造格」的空地写进场景。

## 随机起始帧 + 随机播放速度，避免一排装饰物整齐划一地动
@export var random_start := true
## 进场景时把节点对齐到所在格子的中心
@export var snap_to_grid := true

@onready var anim: AnimatedSprite2D = $anim


func _ready() -> void:
	if snap_to_grid:
		_snap_to_cell()
	if anim == null or anim.sprite_frames == null:
		return
	if not anim.sprite_frames.has_animation("default"):
		return
	var n := anim.sprite_frames.get_frame_count("default")
	if random_start and n > 1:
		anim.frame = randi() % n
		anim.speed_scale = randf_range(0.85, 1.2)
	anim.play("default")


## 本实例覆盖的格子（中心坐标 → 格子索引）
func get_grid() -> Vector2i:
	var t: int = StageData.TileSize
	return Vector2i(floori(position.x / t), floori(position.y / t))


func _snap_to_cell() -> void:
	var t: int = StageData.TileSize
	position = Vector2(get_grid() * t) + Vector2(t, t) * 0.5
