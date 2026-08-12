extends PanelContainer


@onready var img = $VBoxContainer/img
@onready var costLabel = $VBoxContainer/MarginContainer/HBoxContainer/costLabel

@export var type: Game.towerType = Game.towerType.gunTower

func setImg(obj):
	img.texture = obj
	
func setCost(cost):
	costLabel.text = str(cost)
