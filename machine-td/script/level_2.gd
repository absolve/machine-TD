extends "res://script/base_level.gd"

func _ready():
	super._ready()
	# 横向蛇形 4 通道（左进→右出），通道间开阔区，含 2x2 放置块
	allowArea.append_array([
		# 通道间第一段
		Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5), Vector2i(10, 5),
		Vector2i(5, 6), Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 6), Vector2i(9, 6), Vector2i(10, 6),
		# 通道间第二段
		Vector2i(12, 8), Vector2i(13, 8), Vector2i(14, 8), Vector2i(15, 8), Vector2i(16, 8), Vector2i(17, 8), Vector2i(18, 8),
		Vector2i(12, 9), Vector2i(13, 9), Vector2i(14, 9), Vector2i(15, 9), Vector2i(16, 9), Vector2i(17, 9), Vector2i(18, 9),
		# 通道间第三段
		Vector2i(20, 10), Vector2i(21, 10), Vector2i(22, 10), Vector2i(23, 10), Vector2i(24, 10),
		Vector2i(20, 11), Vector2i(21, 11), Vector2i(22, 11), Vector2i(23, 11), Vector2i(24, 11)
	])
