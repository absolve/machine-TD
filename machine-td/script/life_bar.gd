extends Node2D

@onready var bar = $ProgressBar
@onready var timer = $Timer

@export var maxHp = 100:
	set(v):
		maxHp = v
		bar.max_value = v
		
@export var value = 100:
	set(v):
		value = v
		bar.value = v
		bar.visible = true
		timer.stop()
		timer.start()

func _ready():
	bar.max_value = maxHp
	bar.value = value
	bar.visible = false


func _on_timer_timeout() -> void:
	bar.visible = false
