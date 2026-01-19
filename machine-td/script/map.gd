extends Node2D


@onready var towerShadow=$towerShadow



func _ready():
	Game.map=self
	Game.selectTower.connect(selectTower)
	
	
#选中塔
func selectTower(item):
	print(item)
	towerShadow.setActive()
	


func _unhandled_input(_event):
	
	if Input.is_action_just_pressed("click"):
		print(towerShadow.placable)
	
	
	if Input.is_action_just_pressed("selectCancel"):
		if towerShadow.active:
			towerShadow.setInactive()
			print(Rect2(towerShadow.global_position-towerShadow.shape.shape.get_rect().size/2,towerShadow.shape.shape.get_rect().size))
