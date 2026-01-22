extends Control


@onready var itemList=$fc/vbox/ItemList
@onready var towerName=$fc/vbox/towerInfo/panel/vbox/towerName
@onready var towerDetail=$fc/vbox/towerInfo/panel/vbox/towerDetail
@onready var towerInfo=$fc/vbox/towerInfo
@onready var atkLabel=$fc/vbox/towerInfo/panel/vbox/hbox/hbox1/atkLabel
@onready var costLabel=$fc/vbox/towerInfo/panel/vbox/hbox/hbox2/costLabel
@onready var reloadLabel=$fc/vbox/towerInfo/panel/vbox/hbox/hbox3/reloadLabel

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
	itemList.set_item_text(0,"gunTower")
	itemList.set_item_text(1,"cannonTower")
	itemList.set_item_text(2,"rocketTower")

func setTowerDetail(obj):
	towerName.text=str(obj.name)
	towerDetail.text=str(obj.desc)
	atkLabel.text=str(obj.atk)
	costLabel.text=str(obj.cost)
	reloadLabel.text=str(obj.reload)


func _on_item_list_item_selected(index: int) -> void:
	towerInfo.visible=true
	print(itemList.get_item_metadata(index))
	var type=itemList.get_item_metadata(index)
	var temp= Game.towerInfo.get(type)
	towerInfo.type=type
	towerInfo.cost=temp.cost
	setTowerDetail(temp)
	Game.selectTower.emit(itemList.get_item_metadata(index))
