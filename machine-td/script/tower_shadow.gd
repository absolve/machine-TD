extends Area2D


@onready var shape = $shape
@onready var ani = $ani

var placeable = false # 可放置
var active = false # 是否活动
var towerType = Game.towerType.machineGunTower # 类型
var cost = 0 # 花费
var gridSize: Vector2i = Vector2i(1, 1) # 占用的网格宽高 (列, 行)
var drawColor = Color.INDIAN_RED # 绘制颜色

func _ready():
	#print(shape.shape.get_rect())
	visible = false

func setActive():
	active = true
	visible = true
	if towerType == Game.towerType.machineGunTower:
		ani.play("gun")
	elif towerType == Game.towerType.cannonTower:
		ani.play("cannon")
	elif towerType == Game.towerType.rocketTower:
		ani.play("rocket")

func setInactive():
	active = false
	visible = false
	placeable = false

func _physics_process(_delta: float) -> void:
	if active:
		if !placeable:
			drawColor = Color.INDIAN_RED
		else:
			drawColor = Color.GREEN

		queue_redraw()
		pass

func _draw() -> void:
	@warning_ignore("integer_division")
	var half_x: int = gridSize.x / 2
	@warning_ignore("integer_division")
	var half_y: int = gridSize.y / 2

	var start: Vector2 = Vector2.ZERO - Vector2(half_x, half_y)

	for dx in range(gridSize.x):
		for dy in range(gridSize.y):
			draw_rect(Rect2((start + Vector2(dx, dy) -
			Vector2(StageData.TileSize, StageData.TileSize) / 2),
			Vector2(StageData.TileSize, StageData.TileSize)), drawColor)
	

# func _physics_process(_delta):
# 	if !active:
# 		return
# 	position = get_global_mouse_position()
# 	var areas = get_overlapping_areas()
# 	if areas:
# 		placeable = false
# 		var ownRect = Rect2(global_position - shape.shape.get_rect().size / 2,
# 		shape.shape.get_rect().size)
# 		var hasTower = false
# 		for i in areas:
# 			var shape1 = i.get_node("shape")
# 			var otherRect = Rect2(i.global_position - shape1.shape.get_rect().size / 2,
# 				shape1.shape.get_rect().size)
# 			if i is Tower: # 判断塔是不是重叠
# 				if otherRect.intersects(ownRect):
# 					hasTower = true
# 			else:
# 				if otherRect.encloses(ownRect):
# 					placeable = true
# 		if hasTower:
# 			#print('hasTower',hasTower)
# 			placeable = false
# 	else:
# 		placeable = false

# func _input(_event: InputEvent) -> void:
# 	if Input.is_action_just_pressed("click"):
# 		if placeable:
# 			Game.placeTower.emit(towerType)
		
# 	if Input.is_action_just_pressed("selectCancel"):
# 		if active:
# 			setInactive()
	
#func _unhandled_input(_event:InputEvent):
	#if Input.is_action_just_pressed("click"):
		#print(placable)
		#if placable:
			#print('placa')
			#Game.placeTower.emit(towerType)
			#get_viewport().set_input_as_handled()
	#if Input.is_action_just_pressed("selectCancel"):
		#if active:
			#setInactive()
