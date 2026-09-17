extends "res://script/base_level.gd"
## 教程关：可建造区和传送带都不再是 TileMap 瓦片，改成关卡里摆的场景实例。
##   - 可建造格 → scene/placeable_area.tscn（由 base_level.gd::_collect_allow_area 自动收集）
##   - 传送带   → scene/belt.tscn（第 4 行整行，西进东出）

func _ready() -> void:
	super._ready()
