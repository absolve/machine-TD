extends "res://script/level/base_level.gd"
## 可建造区和传送带都是关卡里摆的场景实例，不是 TileMap 瓦片：
##   - 可建造格 -> scene/placeable_area.tscn（base_level.gd::_collect_allow_area 自动收集）
##   - 传送带   -> scene/belt.tscn（贴在路线上，方向由贴图文件名决定）

func _ready() -> void:
	super._ready()
