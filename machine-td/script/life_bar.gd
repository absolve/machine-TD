extends Node2D

@export var maxHp: int = 100:
	set(newValue):
		maxHp = newValue
		bar.max_value = newValue

@export var value: int = 100:
	set(newValue):
		value = newValue
		bar.value = newValue
		bar.visible = true
		timer.stop()
		timer.start()

@onready var bar: ProgressBar = $ProgressBar
@onready var timer: Timer = $Timer


func _ready() -> void:
	bar.max_value = maxHp
	bar.value = value
	bar.visible = false


func onTimerTimeout() -> void:
	bar.visible = false
