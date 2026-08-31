extends "res://script/base_level.gd"

func _ready():
	super._ready()
	allowArea.append_array([
		Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7), Vector2i(8, 7),
		Vector2i(9, 7), Vector2i(9, 6), Vector2i(9, 5), Vector2i(10, 5),
		Vector2i(11, 5), Vector2i(12, 5), Vector2i(13, 5), Vector2i(14, 5),
		Vector2i(14, 6), Vector2i(14, 7), Vector2i(15, 7), Vector2i(16, 7),
		Vector2i(17, 7), Vector2i(18, 7), Vector2i(18, 8), Vector2i(19, 8)
	])
