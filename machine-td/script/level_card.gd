extends PanelContainer

@export var level = 1 # 关卡名字
@export var rating = 0 # 评分
@export var description = '' # 关卡描述
@export var isLock = true
@export var levelId = 1 # 关卡id

@onready var num = $VBoxContainer/num
@onready var levelRating = $VBoxContainer/MarginContainer/levelRating
@onready var selected = $selected
@onready var lockLabel = $lockLabel

signal click

func _ready() -> void:
	num.text = str(level)
	# 锁标文本原本是场景里硬编码的英文 "LOCKED"，这里走翻译
	lockLabel.text = tr("_LevelLocked")
	levelRating.rating = rating
	levelRating.visible = true
	levelRating.modulate.a = 1.0 if rating > 0 else 0.0
	if isLock:
		modulate = Color(0.45, 0.45, 0.45, 0.75)
		lockLabel.visible = true
	else:
		lockLabel.visible = false


func _on_mouse_entered() -> void:
	selected.visible = not isLock


func _on_mouse_exited() -> void:
	selected.visible = false


func _on_gui_input(_event):
	if _event is InputEventMouseButton && _event.is_action_pressed("click"):
		if !isLock:
			click.emit(levelId)
