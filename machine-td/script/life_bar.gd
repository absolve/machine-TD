extends Node2D

@onready var bar=$ProgressBar

@export var maxHp=100
@export var value=100:
	set(v):
		value=v
		bar.value=v


func _ready():
	bar.max_value=maxHp
	bar.value=value

#设置生命值
#func setValue(v):
	#value=v
