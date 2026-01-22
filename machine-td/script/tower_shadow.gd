extends Area2D


@onready var shape=$shape
@onready var ani=$ani

var placable = false  #可放置
var active=false #是否活动
var towerType=Game.towerType.gunTower #类型
var cost=0 #花费

func _ready():
	print(shape.shape.get_rect()) 
	
	pass

func setActive():
	active=true
	ani.visible=true


func setInactive():
	active=false
	ani.visible=false
	placable=false
	
func _physics_process(_delta):
	if !active:
		return
	position=get_global_mouse_position()
	var areas=get_overlapping_areas()
	if areas:
		placable=false
		var ownRect=Rect2(global_position-shape.shape.get_rect().size/2,
		shape.shape.get_rect().size)
		for i in areas:
			if i is Tower: #判断塔是不是重叠
				pass
			var shape1=i.get_node("shape")
			var otherRect=Rect2(i.global_position-shape1.shape.get_rect().size/2,
				shape1.shape.get_rect().size)
			if 	otherRect.encloses(ownRect):
				placable=true
	else:
		placable=false


func _unhandled_input(_event):
	if Input.is_action_just_pressed("click"):
		print(placable)
		if placable:
			print('placa')
			Game.placeTower.emit(towerType)
	if Input.is_action_just_pressed("selectCancel"):
		if active:
			setInactive()
