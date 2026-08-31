extends "res://script/base_level.gd"

func _ready():
	super._ready()
	# U 形拱门路线（上进→右出），拱门内部开阔区，含 2x2 放置块
	allowArea.append_array([
		# 拱门内部上部平台
		Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4), Vector2i(9, 4), Vector2i(10, 4),
		Vector2i(11, 4), Vector2i(12, 4), Vector2i(13, 4), Vector2i(14, 4), Vector2i(15, 4),
		Vector2i(16, 4), Vector2i(17, 4), Vector2i(18, 4), Vector2i(19, 4), Vector2i(20, 4),
		Vector2i(21, 4), Vector2i(22, 4), Vector2i(23, 4),
		Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5), Vector2i(10, 5),
		Vector2i(11, 5), Vector2i(12, 5), Vector2i(13, 5), Vector2i(14, 5), Vector2i(15, 5),
		Vector2i(16, 5), Vector2i(17, 5), Vector2i(18, 5), Vector2i(19, 5), Vector2i(20, 5),
		Vector2i(21, 5), Vector2i(22, 5), Vector2i(23, 5),
		# 拱门内部中部
		Vector2i(12, 7), Vector2i(13, 7), Vector2i(14, 7), Vector2i(15, 7), Vector2i(16, 7), Vector2i(17, 7),
		Vector2i(12, 8), Vector2i(13, 8), Vector2i(14, 8), Vector2i(15, 8), Vector2i(16, 8), Vector2i(17, 8)
	])
