extends "res://script/base_level.gd"

func _ready():
	super._ready()
	allowArea.append_array([
		Vector2i(4, 8), Vector2i(5, 8), Vector2i(6, 8), Vector2i(7, 8),
		Vector2i(7, 7), Vector2i(7, 6), Vector2i(8, 6), Vector2i(9, 6),
		Vector2i(10, 6), Vector2i(11, 6), Vector2i(12, 6), Vector2i(13, 6),
		Vector2i(14, 7), Vector2i(14, 8), Vector2i(15, 8), Vector2i(16, 8),
		Vector2i(17, 8), Vector2i(17, 7), Vector2i(18, 7), Vector2i(19, 7)
	])
