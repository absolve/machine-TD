extends "res://script/base_level.gd"

func _ready():
	super._ready()
	# 竖向蛇形 6 通道（上进→下出），通道间含 2x2 放置块
	allowArea.append_array([
		# 通道间第一段
		Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4), Vector2i(9, 4),
		Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5),
		# 通道间第二段
		Vector2i(17, 4), Vector2i(18, 4), Vector2i(19, 4), Vector2i(20, 4), Vector2i(21, 4),
		Vector2i(17, 5), Vector2i(18, 5), Vector2i(19, 5), Vector2i(20, 5), Vector2i(21, 5),
		# 通道间第三段
		Vector2i(11, 8), Vector2i(12, 8), Vector2i(13, 8), Vector2i(14, 8), Vector2i(15, 8),
		Vector2i(11, 9), Vector2i(12, 9), Vector2i(13, 9), Vector2i(14, 9), Vector2i(15, 9),
		# 通道间第四段
		Vector2i(23, 10), Vector2i(24, 10), Vector2i(25, 10), Vector2i(26, 10),
		Vector2i(23, 11), Vector2i(24, 11), Vector2i(25, 11), Vector2i(26, 11),
		# 尾部补充
		Vector2i(6, 11), Vector2i(7, 11), Vector2i(8, 11), Vector2i(9, 11),
		Vector2i(6, 12), Vector2i(7, 12), Vector2i(8, 12), Vector2i(9, 12)
	])
