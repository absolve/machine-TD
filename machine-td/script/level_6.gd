extends "res://script/base_level.gd"

func _ready():
	super._ready()
	# Z 字形路线（右进→左出），折线之间开阔区，含 2x2 放置块
	allowArea.append_array([
		# 第一段水平带
		Vector2i(11, 4), Vector2i(12, 4), Vector2i(13, 4), Vector2i(14, 4), Vector2i(15, 4),
		Vector2i(16, 4), Vector2i(17, 4), Vector2i(18, 4), Vector2i(19, 4), Vector2i(20, 4),
		Vector2i(11, 5), Vector2i(12, 5), Vector2i(13, 5), Vector2i(14, 5), Vector2i(15, 5),
		Vector2i(16, 5), Vector2i(17, 5), Vector2i(18, 5), Vector2i(19, 5), Vector2i(20, 5),
		# 中部
		Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 6), Vector2i(9, 6),
		Vector2i(4, 7), Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7), Vector2i(8, 7), Vector2i(9, 7),
		# 尾部
		Vector2i(13, 8), Vector2i(14, 8), Vector2i(15, 8), Vector2i(16, 8), Vector2i(17, 8), Vector2i(18, 8),
		Vector2i(13, 9), Vector2i(14, 9), Vector2i(15, 9), Vector2i(16, 9), Vector2i(17, 9), Vector2i(18, 9)
	])
