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
	Game.defeatEnemy.connect(defeatEnemy)
	Game.enemyEscape.connect(enemyEscape)
	#加载关卡
	
	titleNode.hp=level.health
	titleNode.wave=level.wave
	titleNode.money=level.money
	#titleNode.score=level.score
	titleNode.start.connect(startGame)
	titleNode.pause.connect(pauseGame)
	titleNode.soundOn.connect(soundOn)
	titleNode.soundOff.connect(soundOff)
	titleNode.musicOn.connect(musicOn)
	titleNode.musicOff.connect(musicOff)
	titleNode.home.connect(home)
	titleNode.speedOn.connect(speedOn)
	titleNode.speedOff.connect(speedOff)
	
#选中塔
func selectTower(item):
	print(item)
	var temp= Game.towerInfo.get(item)
	towerShadow.cost=temp.cost
	towerShadow.towerType=item
	towerShadow.setActive()
	for i in get_tree().get_nodes_in_group("placeableArea"):
		i.isShow=true
	
#放着塔
func placeTower(type):
	print(type)
	if titleNode.money<towerShadow.cost:
		print('Insufficient funds')
		return
	var temp=null	
	titleNode.money-=towerShadow.cost
	if type==Game.towerType.gunTower:
		temp=gunTower.instantiate()
	elif type==Game.towerType.cannonTower:
		temp=cannonTower.instantiate()	
	elif type==Game.towerType.rocketTower:
		temp=rocketTower.instantiate()		
	temp.position=towerShadow.position

	level.add_child(temp)
	#towerShadow.setInactive()
	
		
		
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

#获得奖励
func defeatEnemy(point):
	titleNode.money+=point

#敌人逃脱
func enemyEscape(point):
	if titleNode.hp-point<0:
		print('game over')
	titleNode.hp-=point

func startGame():
	get_tree().paused = false
	level.start()

func pauseGame():
	get_tree().paused = true

func soundOn():
	pass
	
func soundOff():
	pass
	
func musicOn():
	pass
	
func musicOff():
	pass			

func home():
	pass

func speedOn():
	pass
	
func speedOff():
	pass	
	
func _on_button_pressed():
	level.start()

func _unhandled_input(_event):
	if Input.is_action_just_pressed("selectCancel"):
		for i in get_tree().get_nodes_in_group("placeableArea"):
			i.isShow=false
		towerShadow.setInactive()
