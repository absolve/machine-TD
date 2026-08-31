extends "res://script/base_level.gd"

func _ready():
	super._ready()
	allowArea.append_array([
		Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5),
		Vector2i(8, 5), Vector2i(9, 5), Vector2i(10, 4), Vector2i(10, 5),
		Vector2i(10, 6), Vector2i(11, 6), Vector2i(12, 6), Vector2i(13, 6),
		Vector2i(14, 6), Vector2i(15, 7), Vector2i(15, 8), Vector2i(16, 8),
		Vector2i(17, 8), Vector2i(18, 8), Vector2i(18, 9), Vector2i(19, 9)
	])
