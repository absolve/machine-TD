extends Control


@onready var info = $towerInfo
@onready var towerList = $fc/vbox/ScrollContainer/towerList
@onready var towerCardList = $ScrollContainer/PanelContainer/vbox


var towerCard = preload("res://scene/tower_card.tscn")


var tower1 = preload("res://sprite/tower1.png")
var tower2 = preload("res://sprite/tower2.png")
var tower3 = preload("res://sprite/tower3.png")
var towerIcon = preload("res://scene/tower_icon.tscn")

var towersData = [ {'type': 1000, 'img': tower1},
{'type': 1001, 'img': tower2}, {'type': 1002, 'img': tower3}]


func _ready() -> void:
	# for i in towersData:
	# 	var towerIcon1 = towerIcon.instantiate()
	# 	towerIcon1.type = i.type
	# 	towerIcon1.texture = i.img
	# 	towerIcon1.showInfo.connect(showInfo)
	# 	towerIcon1.hideInfo.connect(hideInfo)
	# 	towerIcon1.select.connect(itemSelect)
	# 	towerList.add_child(towerIcon1)
	for i in towersData:
		var towerCard1 = towerCard.instantiate()
		towerCardList.add_child(towerCard1)
		towerCard1.setImg(i.img)
		towerCard1.type = i.type
		var temp = Game.towerInfo.get(i.type)
		towerCard1.setCost(temp.cost)
		towerCard1.connect("click",towerClick)
		
#func showInfo(_type):
	#var temp = Game.towerInfo.get(_type)
	#info.showDetail(temp)
	#info.global_position = get_global_mouse_position()
	#info.visible = true
	#
#func hideInfo(_type):
	#info.visible = false
#
#func itemSelect(_type):
	#Game.selectTower.emit(_type)


func towerClick(type):
	print(type)
	Game.selectTower.emit(type)
	pass
