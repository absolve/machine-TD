extends Node2D


@onready var towerShadow=$towerShadow
@onready var titleNode=$hud/title
@onready var towerUINode=$hud/towerUI
@onready var level=$level1

var gunTower=preload("res://scene/gunTower.tscn")
var rocketTower=preload("res://scene/rocketTower.tscn")
var cannonTower=preload("res://scene/cannonTower.tscn")

func _ready():
	print("map")
	Game.map=self
	Game.selectTower.connect(selectTower)
	Game.placeTower.connect(placeTower)
	Game.refreshData.connect(refreshData)
	#加载关卡
	
	titleNode.hp=level.health
	titleNode.wave=level.wave
	titleNode.money=level.money
	#titleNode.score=level.score

	
#选中塔
func selectTower(item):
	print(item)
	towerShadow.setActive()
	
#放着塔
func placeTower(type):
	print(type)
	
	if type==Game.towerType.gunTower:
		if titleNode.money>towerShadow.cost:
			titleNode.money-=towerShadow.cost
			var temp=gunTower.instantiate()
			temp.position=towerShadow.position
			level.add_child(temp)
			towerShadow.setInactive()
		else:
			print('Insufficient funds')

#更新游戏中数据
func refreshData(dict):
	print(dict)
	if dict.hp:
		titleNode.hp=dict.hp
	if dict.wave:
		titleNode.wave=dict.wave
	if 	dict.money:
		titleNode.money=dict.money
	if 	dict.score:
		titleNode.score=dict.score

func _unhandled_input(_event):
	
	pass
