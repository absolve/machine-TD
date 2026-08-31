extends "res://script/base_level.gd"

func _ready():
	super._ready()
	# 螺旋形路线（右进→中心出），螺旋环之间空隙放塔，含 2x2 放置块
	allowArea.append_array([
		Vector2i(8, 4), Vector2i(10, 4), Vector2i(11, 4), Vector2i(12, 4), Vector2i(13, 4), Vector2i(14, 4),
		Vector2i(21, 4), Vector2i(22, 4), Vector2i(23, 4),
		Vector2i(8, 5), Vector2i(10, 5), Vector2i(11, 5), Vector2i(12, 5), Vector2i(18, 5), Vector2i(19, 5),
		Vector2i(21, 5), Vector2i(22, 5), Vector2i(23, 5),
		Vector2i(8, 6), Vector2i(10, 6), Vector2i(11, 6), Vector2i(12, 6), Vector2i(14, 6), Vector2i(15, 6),
		Vector2i(16, 6), Vector2i(18, 6), Vector2i(19, 6), Vector2i(21, 6), Vector2i(22, 6), Vector2i(23, 6),
		Vector2i(8, 7), Vector2i(10, 7), Vector2i(11, 7), Vector2i(12, 7), Vector2i(14, 7), Vector2i(15, 7),
		Vector2i(16, 7), Vector2i(18, 7), Vector2i(19, 7), Vector2i(21, 7), Vector2i(22, 7), Vector2i(23, 7),
		Vector2i(8, 8), Vector2i(10, 8), Vector2i(11, 8), Vector2i(12, 8), Vector2i(14, 8), Vector2i(18, 8), Vector2i(19, 8),
		Vector2i(8, 9), Vector2i(10, 9), Vector2i(11, 9), Vector2i(12, 9), Vector2i(14, 9), Vector2i(15, 9),
		Vector2i(16, 9), Vector2i(17, 9), Vector2i(18, 9), Vector2i(19, 9),
		Vector2i(7, 10), Vector2i(8, 10), Vector2i(7, 11), Vector2i(8, 11)
	])
