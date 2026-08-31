extends "res://script/base_level.gd"

func _ready():
	super._ready()
	# 竖向蛇形 4 通道（上进→下出），通道间含 2x2 放置块
	allowArea.append_array([
		# 通道间第一段
		Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4), Vector2i(9, 4), Vector2i(10, 4),
		Vector2i(11, 4), Vector2i(12, 4), Vector2i(13, 4), Vector2i(14, 4),
		Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5), Vector2i(10, 5),
		Vector2i(11, 5), Vector2i(12, 5), Vector2i(13, 5), Vector2i(14, 5),
		# 通道间第二段
		Vector2i(16, 8), Vector2i(17, 8), Vector2i(18, 8), Vector2i(19, 8), Vector2i(20, 8),
		Vector2i(21, 8), Vector2i(22, 8), Vector2i(23, 8),
		Vector2i(16, 9), Vector2i(17, 9), Vector2i(18, 9), Vector2i(19, 9), Vector2i(20, 9),
		Vector2i(21, 9), Vector2i(22, 9), Vector2i(23, 9),
		# 通道间第三段
		Vector2i(25, 11), Vector2i(26, 11), Vector2i(27, 11), Vector2i(28, 11),
		Vector2i(25, 12), Vector2i(26, 12), Vector2i(27, 12), Vector2i(28, 12)
	])
