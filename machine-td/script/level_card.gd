extends PanelContainer

@export var level = 1 # 关卡名字
@export var rating = 0 # 评分
@export var description = '' # 关卡描述
@export var isLock = true

@onready var num = $VBoxContainer/num
@onready var levelRating=$VBoxContainer/MarginContainer/levelRating
@onready var selected=$selected


func _ready() -> void:
	num.text = str(level)
	levelRating.rating=rating


func _on_mouse_entered() -> void:
	selected.visible=true


func _on_mouse_exited() -> void:
	selected.visible=false


func _on_gui_input(_event):
	if Input.is_action_just_pressed("click"):
		print('click')
