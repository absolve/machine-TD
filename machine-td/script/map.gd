extends Node2D


@onready var towerShadow=$towerShadow
@onready var titleNode=$hud/title
@onready var towerUINode=$hud/towerUI
@onready var level=$level1

var gunTower=preload("res://scene/gunTower.tscn")
var rocketTower=preload("res://scene/rocketTower.tscn")
var cannonTower=preload("res://scene/cannonTower.tscn")

func _ready():
	Game.map=self
	Game.selectTower.connect(selectTower)
	Game.placeTower.connect(placeTower)
	
#选中塔
func selectTower(item):
	print(item)
	towerShadow.setActive()
	
#放着塔
func placeTower(type):
	print(type)
	if type==Game.towerType.gunTower:
		var temp=gunTower.instantiate()
		temp.position=towerShadow.position
		level.add_child(temp)
		towerShadow.setInactive()


func _unhandled_input(_event):
	
	pass
