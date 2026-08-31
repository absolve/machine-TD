extends "res://script/base_level.gd"

func _ready():
	super._ready()
	allowArea.append_array([
		Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6), Vector2i(7, 6),
		Vector2i(8, 6), Vector2i(8, 7), Vector2i(8, 8), Vector2i(9, 8),
		Vector2i(10, 8), Vector2i(11, 8), Vector2i(12, 7), Vector2i(12, 6),
		Vector2i(13, 6), Vector2i(14, 6), Vector2i(14, 7), Vector2i(14, 8),
		Vector2i(15, 8), Vector2i(15, 9), Vector2i(16, 9), Vector2i(17, 9)
	])
