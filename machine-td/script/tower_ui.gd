extends Control


@onready var itemList=$fc/vbox/ItemList
@onready var towerName=$fc/vbox/towerInfo/panel/vbox/towerName
@onready var towerDetail=$fc/vbox/towerInfo/panel/vbox/towerDetail
@onready var towerInfo=$fc/vbox/towerInfo
@onready var atkLabel=$fc/vbox/towerInfo/panel/vbox/hbox/hbox1/atkLabel
@onready var costLabel=$fc/vbox/towerInfo/panel/vbox/hbox/hbox2/costLabel
@onready var reloadLabel=$fc/vbox/towerInfo/panel/vbox/hbox/hbox3/reloadLabel

@onready var info=$towerInfo
@onready var towerList=$fc/vbox/ScrollContainer/towerList


var tower1 =preload("res://sprite/tower1.png")
var tower2=preload("res://sprite/tower2.png")
var tower3=preload("res://sprite/tower3.png")
var towerIcon=preload("res://scene/tower_icon.tscn")


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
	
	var towerIcon1=towerIcon.instantiate()
	towerIcon1.type="gunTower"
	towerIcon1.texture=tower1
	towerIcon1.showInfo.connect(showInfo)
	towerIcon1.hideInfo.connect(hideInfo)
	towerList.add_child(towerIcon1)


func setTowerDetail(obj):
	towerName.text=str(obj.name)
	towerDetail.text=str(obj.desc)
	atkLabel.text=str(obj.atk)
	costLabel.text=str(obj.cost)
	reloadLabel.text=str(obj.reload)


func showInfo(_type):
	pass
	
func hideInfo(_type):
	
	pass

func _on_item_list_item_selected(index: int) -> void:
	#towerInfo.visible=true
	print(itemList.get_item_metadata(index))
	var type=itemList.get_item_metadata(index)
	var temp= Game.towerInfo.get(type)
	setTowerDetail(temp)
	Game.selectTower.emit(itemList.get_item_metadata(index))
