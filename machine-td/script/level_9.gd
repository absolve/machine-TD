extends "res://script/base_level.gd"

func _ready():
	super._ready()
	allowArea.append_array([
		Vector2i(4, 8), Vector2i(5, 8), Vector2i(6, 8), Vector2i(7, 8),
		Vector2i(8, 8), Vector2i(8, 7), Vector2i(9, 7), Vector2i(10, 7),
		Vector2i(11, 7), Vector2i(12, 7), Vector2i(13, 7), Vector2i(14, 7),
		Vector2i(14, 6), Vector2i(15, 6), Vector2i(16, 6), Vector2i(17, 6),
		Vector2i(18, 6), Vector2i(18, 7), Vector2i(18, 8), Vector2i(19, 8)
	])
