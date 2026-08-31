extends "res://script/base_level.gd"

func _ready():
	super._ready()
	# 复合蛇形 5 通道（左进→右出），通道间含 2x2 放置块
	allowArea.append_array([
		# 通道间第一段
		Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4),
		Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5),
		# 通道间第二段
		Vector2i(16, 4), Vector2i(17, 4), Vector2i(18, 4), Vector2i(19, 4), Vector2i(20, 4),
		Vector2i(16, 5), Vector2i(17, 5), Vector2i(18, 5), Vector2i(19, 5), Vector2i(20, 5),
		# 通道间第三段
		Vector2i(10, 8), Vector2i(11, 8), Vector2i(12, 8), Vector2i(13, 8), Vector2i(14, 8),
		Vector2i(10, 9), Vector2i(11, 9), Vector2i(12, 9), Vector2i(13, 9), Vector2i(14, 9),
		# 通道间第四段
		Vector2i(22, 10), Vector2i(23, 10), Vector2i(24, 10)
	])
