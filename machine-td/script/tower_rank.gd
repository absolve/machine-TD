extends Node2D

@onready var ani = $ani
@export var level = 1 # 等级

func _ready() -> void:
	if level > 1:
		ani.show()
		ani.play("lv" + str(level))
	else:
		ani.hide()

# 设置等级
func setLevel(_level: int) -> void:
	self.level = _level
	if _level > 1:
		ani.show()
		ani.play("lv" + str(_level))
	else:
		ani.hide()
