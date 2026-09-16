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
	# 动画名 = 塔类型名（tower_shadow.tscn 里每种塔一条动画）
	var anim := "machineGunTower"
	match towerType:
		Game.towerType.cannonTower: anim = "cannonTower"
		Game.towerType.rocketTower: anim = "rocketTower"
		Game.towerType.EMPTower: anim = "EMPTower"
		Game.towerType.teslaCoilTower: anim = "teslaCoilTower"
		Game.towerType.laserTower: anim = "laserTower"
		Game.towerType.droneBase: anim = "droneBase"
		_: anim = "machineGunTower"
	ani.play(anim)

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
	# 半透明填充色, 让网格线清晰可见
	var fill_color = Color(drawColor, 0.3)
	for dx in range(gridSize.x):
		for dy in range(gridSize.y):
			# 每个格子的左上角 = top_left + (dx, dy) * TileSize
			var cell_pos: Vector2 = top_left + Vector2(dx * tile, dy * tile)
			# 半透明填充
			draw_rect(Rect2(cell_pos, Vector2(tile, tile)), fill_color, true)
			# 网格边框
			draw_rect(Rect2(cell_pos, Vector2(tile, tile)), drawColor, false, 2.0)
	
