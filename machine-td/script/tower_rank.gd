extends Node2D

@export var level: int = 1 # 等级

@onready var ani: AnimatedSprite2D = $Ani


func _ready() -> void:
	if level > 1:
		ani.show()
		ani.play("lv" + str(level))
	else:
		ani.hide()


# 设置等级
func setLevel(newLevel: int) -> void:
	level = newLevel
	if newLevel > 1:
		ani.show()
		ani.play("lv" + str(newLevel))
	else:
		ani.hide()
