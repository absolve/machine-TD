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
	print(gridSize)

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


func _draw() -> void:
	var tile: int = StageData.TileSize
	# 以原点为中心,计算整个占用区域的左上角(像素坐标)
	var half: Vector2 = Vector2(gridSize.x * tile, gridSize.y * tile) * 0.5
	var top_left: Vector2 = Vector2.ZERO - half
	for dx in range(gridSize.x):
		for dy in range(gridSize.y):
			# 每个格子的左上角 = top_left + (dx, dy) * TileSize
			var cell_pos: Vector2 = top_left + Vector2(dx * tile, dy * tile)
			draw_rect(Rect2(cell_pos, Vector2(tile, tile)), drawColor)
	
