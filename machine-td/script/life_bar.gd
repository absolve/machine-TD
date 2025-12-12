extends Node2D

@export var maxHp=100
@export var value=100

@onready var bar=$ProgressBar

func _ready():
	bar.max_value=maxHp
	bar.value=value

#设置生命值
func setValue(v):
	value=v
