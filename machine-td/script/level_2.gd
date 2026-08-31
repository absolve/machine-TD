extends "res://script/base_level.gd"

func _ready():
	super._ready()
	# 工厂路线的可放置区域，适合中期防御塔的布局
	allowArea.append_array([
		Vector2i(5, 6), Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 6),
		Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7), Vector2i(8, 7),
		Vector2i(9, 5), Vector2i(9, 6), Vector2i(9, 7), Vector2i(9, 8),
		Vector2i(11, 4), Vector2i(12, 4), Vector2i(12, 5), Vector2i(12, 6),
		Vector2i(13, 6), Vector2i(13, 7), Vector2i(13, 8), Vector2i(14, 8),
		Vector2i(15, 8), Vector2i(16, 8), Vector2i(16, 9), Vector2i(17, 9)
	])
