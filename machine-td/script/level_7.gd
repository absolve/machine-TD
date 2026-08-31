extends "res://script/base_level.gd"

func _ready():
	super._ready()
	# M/W 形路线（左进→右出），波峰波谷间开阔区，含 2x2 放置块
	allowArea.append_array([
		# 第一波谷
		Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4), Vector2i(9, 4), Vector2i(10, 4),
		Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5), Vector2i(10, 5),
		# 第二波谷
		Vector2i(19, 5), Vector2i(20, 5), Vector2i(21, 5), Vector2i(22, 5), Vector2i(23, 5), Vector2i(24, 5),
		# 中部凹槽
		Vector2i(12, 8), Vector2i(13, 8), Vector2i(14, 8), Vector2i(15, 8), Vector2i(16, 8), Vector2i(17, 8),
		Vector2i(12, 9), Vector2i(13, 9), Vector2i(14, 9), Vector2i(15, 9), Vector2i(16, 9), Vector2i(17, 9),
		# 第三波谷
		Vector2i(6, 10), Vector2i(7, 10), Vector2i(8, 10), Vector2i(9, 10),
		Vector2i(6, 11), Vector2i(7, 11), Vector2i(8, 11), Vector2i(9, 11)
	])
