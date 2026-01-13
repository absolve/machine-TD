extends CanvasLayer


@onready var itemList=$Control/VBoxContainer/ItemList
@onready var towerName=$Control/VBoxContainer/towerInfo/PanelContainer/VBoxContainer/towerName
@onready var towerDetail=$Control/VBoxContainer/towerInfo/PanelContainer/VBoxContainer/towerDetail
@onready var towerInfo=$Control/VBoxContainer/towerInfo
@onready var atkLabel=$Control/VBoxContainer/towerInfo/PanelContainer/VBoxContainer/HBoxContainer/HBoxContainer/atkLabel
@onready var costLabel=$Control/VBoxContainer/towerInfo/PanelContainer/VBoxContainer/HBoxContainer/HBoxContainer2/costLabel
@onready var reloadLabel=$Control/VBoxContainer/towerInfo/PanelContainer/VBoxContainer/HBoxContainer/HBoxContainer3/reloadLabel

var tower1 =preload("res://sprite/tower1.png")
var tower2=preload("res://sprite/tower2.png")
var tower3=preload("res://sprite/tower3.png")

func _ready() -> void:
	itemList.add_icon_item(tower1)
	itemList.add_icon_item(tower2)
	itemList.add_icon_item(tower3)
	itemList.set_item_metadata(0,Game.towerType.gunTower)
	itemList.set_item_metadata(1,Game.towerType.cannonTower)
	itemList.set_item_metadata(2,Game.towerType.rocketTower)

func setTowerDetail(type):
	var temp= Game.towerInfo.get(type)
	towerName.text=str(temp.name)
	towerDetail.text=str(temp.desc)
	atkLabel.text=str(temp.atk)
	costLabel.text=str(temp.cost)
	reloadLabel.text=str(temp.reload)


func _on_item_list_item_selected(index: int) -> void:
	print(index)
	towerInfo.visible=true
	print(itemList.get_item_metadata(index))
	setTowerDetail(itemList.get_item_metadata(index))
