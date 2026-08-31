extends "res://script/base_level.gd"

func _ready():
	super._ready()
	# 阶梯形路线（右进→左出），阶梯之间开阔区，含 2x2 放置块
	allowArea.append_array([
		# 阶梯第一平台
		Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4),
		Vector2i(9, 4), Vector2i(10, 4), Vector2i(11, 4),
		Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5),
		Vector2i(9, 5), Vector2i(10, 5), Vector2i(11, 5),
		# 阶梯第二平台
		Vector2i(21, 4), Vector2i(22, 4), Vector2i(23, 4), Vector2i(24, 4),
		Vector2i(21, 5), Vector2i(22, 5), Vector2i(23, 5), Vector2i(24, 5),
		# 阶梯右侧
		Vector2i(26, 6), Vector2i(27, 6), Vector2i(28, 6), Vector2i(29, 6),
		Vector2i(26, 7), Vector2i(27, 7), Vector2i(28, 7), Vector2i(29, 7),
		# 阶梯第三平台
		Vector2i(15, 8), Vector2i(16, 8), Vector2i(17, 8), Vector2i(18, 8), Vector2i(19, 8),
		Vector2i(15, 9), Vector2i(16, 9), Vector2i(17, 9), Vector2i(18, 9), Vector2i(19, 9)
	])
