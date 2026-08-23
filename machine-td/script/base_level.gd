extends Node2D

@export var levelId: int
@export var wave: int
@export var health: int
@export var money: int

@onready var waveTimer = $waveTimer
@onready var spawnerTimer = $spawnerTimer
@onready var towerShadow = $towerShadow


var currWave = 0
var enemyList = []
var currentSpawner = [] # 当前生产列表

var allowArea: Array[Vector2i] = [] # 允许放置塔的区域
var occupiedArea: Array[Vector2i] = [] # 已占用的区域


func _ready() -> void:
	Game.selectTower.connect(selectTower)
	for i in StageData.allStage:
		if levelId == i.get("id"):
			wave = i.get("wave")
			health = i.get("health")
			money = i.get("money")
			enemyList = i.get("enemySpawner")
			break

# 选择塔
func selectTower(type):
	print(type)
	var temp = Game.towerInfo.get(type)
	towerShadow.cost = temp.cost
	towerShadow.towerType = type
	towerShadow.gridSize = temp.gridSize
	print(temp.gridSize)
	towerShadow.setActive()

# 将世界坐标对齐到网格
func world2Grid(world_pos: Vector2) -> Vector2i:
	var grid_x = floori(world_pos.x / StageData.TileSize)
	var grid_y = floori(world_pos.y / StageData.TileSize)
	return Vector2i(grid_x, grid_y)

# 判断是否可以放置塔
func canPlace(coverGrids: Array[Vector2i]) -> bool:
	for i in coverGrids:
		if i not in allowArea:
			return false
		if i in occupiedArea:
			return false
	return true

# 获取塔占用的网格
func getTowerCoverGrid(center_grid: Vector2i, tower_size: Vector2i) -> Array[Vector2i]:
	var covers: Array[Vector2i] = []
	# 偏移：从中心向左上角偏移一半网格
	@warning_ignore("integer_division")
	var half_x: int = tower_size.x / 2
	@warning_ignore("integer_division")
	var half_y: int = tower_size.y / 2

	var start: Vector2i = center_grid - Vector2i(half_x, half_y)

	for dx in range(tower_size.x):
		for dy in range(tower_size.y):
			covers.append(start + Vector2i(dx, dy))
	return covers


# 隐藏塔阴影
func setShadowHide():
	towerShadow.setInactive()
	queue_redraw()

#添加已占用的区域
func addOccupiedArea(grid: Array[Vector2i]):
	occupiedArea.append_array(grid)
	
	
# 移除已占用的区域
func removeOccupiedArea(grid: Array[Vector2i]):
	for i in grid:
		occupiedArea.erase(i)

func _physics_process(_delta: float) -> void:
	if towerShadow.active:
		towerShadow.position = get_global_mouse_position()
		var grid = world2Grid(towerShadow.position)
		var towerCoverGrid = getTowerCoverGrid(grid, towerShadow.gridSize)
		# print(towerCoverGrid)
		towerShadow.placeable = canPlace(towerCoverGrid)
		# print(towerShadow.placeable)
		queue_redraw()
		if Input.is_action_just_pressed("click"):
			if towerShadow.placeable:
				#var grid = world2Grid(towerShadow.position)
				#var towerCoverGrid = getTowerCoverGrid(grid, towerShadow.gridSize)
				Game.placeTower.emit(towerShadow.towerType, towerShadow.cost, grid, towerCoverGrid, towerShadow.gridSize)
		if Input.is_action_just_pressed("selectCancel"):
			if towerShadow.active:
				towerShadow.setInactive()
				queue_redraw()
	
#func _input(_event: InputEvent) -> void:
	#if towerShadow.active:
		#if Input.is_action_just_pressed("click"):
			#if towerShadow.placeable:
				#var grid = world2Grid(towerShadow.position)
				#var towerCoverGrid = getTowerCoverGrid(grid, towerShadow.gridSize)
				#Game.placeTower.emit(towerShadow.towerType, towerShadow.cost, grid, towerCoverGrid, towerShadow.gridSize)
		#if Input.is_action_just_pressed("selectCancel"):
			#if towerShadow.active:
				#towerShadow.setInactive()
				#queue_redraw()

func _draw() -> void:
	if towerShadow.active:
		var fill_color = Color(Color.SALMON, 0.3)
		var t = StageData.TileSize
		for i in allowArea:
			var cell_pos = Vector2(i.x * t, i.y * t)
			var cell_size = Vector2(t, t)
			# 半透明填充
			draw_rect(Rect2(cell_pos, cell_size), fill_color, true)
			# 网格边框
			draw_rect(Rect2(cell_pos, cell_size), Color.SALMON, false, 2.0)
