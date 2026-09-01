extends "res://script/base_level.gd"

func _ready() -> void:
	super._ready()

	# 教程关卡使用一条简单直线路线，沿路径两侧预留少量可建造区域
	allowArea.append_array([
		Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5), Vector2i(10, 5), Vector2i(11, 5),
		Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 6), Vector2i(9, 6), Vector2i(10, 6), Vector2i(11, 6),
		Vector2i(6, 7), Vector2i(7, 7), Vector2i(8, 7), Vector2i(9, 7), Vector2i(10, 7), Vector2i(11, 7),
		Vector2i(14, 5), Vector2i(15, 5), Vector2i(16, 5), Vector2i(17, 5), Vector2i(18, 5), Vector2i(19, 5),
		Vector2i(14, 6), Vector2i(15, 6), Vector2i(16, 6), Vector2i(17, 6), Vector2i(18, 6), Vector2i(19, 6),
		Vector2i(14, 7), Vector2i(15, 7), Vector2i(16, 7), Vector2i(17, 7), Vector2i(18, 7), Vector2i(19, 7)
	])
