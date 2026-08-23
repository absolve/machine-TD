extends Control


@onready var info = $towerInfo
@onready var towerCardList = $ScrollContainer/PanelContainer/vbox
@onready var player = $player

var isOpen = false
var towerCard = preload("res://scene/tower_card.tscn")


var tower1 = preload("res://sprite/tower1.png")
var tower2 = preload("res://sprite/tower2.png")
var tower3 = preload("res://sprite/tower3.png")
var tower4 = preload("res://sprite/tower3.png")
var tower5 = preload("res://sprite/tower3.png")
var tower6=preload("res://sprite/tower3.png")
var tower7=preload("res://sprite/tower3.png")

var towerIcon = preload("res://scene/tower_icon.tscn")

var towersData = [ {'type': Game.towerType.machineGunTower, 'img': tower1},
{'type': 1001, 'img': tower2}, {'type': 1002, 'img': tower3},
{'type': Game.towerType.EMPTower, 'img': tower4},
{'type': Game.towerType.teslaCoilTower, 'img': tower5},
{'type': Game.towerType.laserTower, 'img': tower6},
{'type': Game.towerType.droneBase, 'img': tower7},
]


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
		towerCard1.connect("click", towerClick)
		towerCard1.showInfo.connect(showTowerInfo)
		towerCard1.connect("mouse_exited", hideTowerInfo)
		
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


func showTowerInfo(type):
	var temp = Game.towerInfo.get(type)
	# 先移到屏幕外，避免在旧位置闪烁
	info.global_position = Vector2(-99999, -99999)
	info.showDetail(temp)
	# 等待一帧让布局更新，获取正确的尺寸
	await get_tree().process_frame
	var info_size = info.size
	var mouse_pos = get_global_mouse_position()
	var viewport_size = get_viewport_rect().size
	# 默认显示在鼠标上方，水平居中对齐鼠标
	var target_pos = Vector2(
		mouse_pos.x - info_size.x / 2.0,
		mouse_pos.y - info_size.y
	)
	# 如果上方超出屏幕，则显示在鼠标下方
	if target_pos.y < 0:
		target_pos.y = mouse_pos.y
	# 限制在屏幕范围内
	target_pos.x = clamp(target_pos.x, 0, max(0, viewport_size.x - info_size.x))
	target_pos.y = clamp(target_pos.y, 0, max(0, viewport_size.y - info_size.y))
	info.global_position = target_pos
	

func hideTowerInfo():
	info.hideDetail()

func towerClick(type):
	print(type)
	Game.selectTower.emit(type)


func _on_icon_gui_input(_event):
	if Input.is_action_just_pressed("click"):
		isOpen = !isOpen
		if isOpen:
			player.play("show")
		else:
			player.play("hide")
