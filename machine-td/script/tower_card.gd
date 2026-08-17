extends PanelContainer


@onready var img = $VBoxContainer/MarginContainer2/img
@onready var costLabel = $VBoxContainer/MarginContainer/HBoxContainer/costLabel
@onready var towerName = $VBoxContainer/MarginContainer3/name
@onready var selected = $selected

@export var type: Game.towerType = Game.towerType.machineGunTower

signal click
signal showInfo

func setImg(obj):
	img.texture = obj
	
func setCost(cost):
	costLabel.text = str(cost)

func setTowerName(n):
	towerName.text = str(n)


func _gui_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("click"):
		click.emit(type)


func _on_mouse_entered() -> void:
	selected.visible = true
	showInfo.emit(type)

func _on_mouse_exited() -> void:
	selected.visible = false
