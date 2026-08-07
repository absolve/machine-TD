extends Node2D

@export var levelId: int
@export var wave: int
@export var health: int
@export var money: int

@onready var waveTimer = $waveTimer
@onready var spawnerTimer = $spawnerTimer



var currWave = 0
var enemyList = []
var currentSpawner = [] # 当前生产列表

var allowArea: Array[Vector2i]=[] #允许放置塔的区域
var occupiedArea: Array[Vector2i]=[] #已占用的区域


func world_to_grid(world_pos: Vector2) -> Vector2i:
	# 将世界坐标对齐到网格
	var grid_x = floor(world_pos.x / StageData.TileSize)
	var grid_y = floor(world_pos.y / StageData.TileSize)
	return Vector2i(grid_x, grid_y)

# 判断是否可以放置塔
func canPlace(coverGrids: Array[Vector2i]) -> bool:
	for i in coverGrids:
		if i in occupiedArea:
			return false
	return true

# 获取塔占用的网格
func getTowerCoverGrid(center_grid: Vector2i, tower_size:Vector2i) -> Array[Vector2i]:
	var covers:Array[Vector2i] = []
	# 偏移：从中心向左上角偏移一半网格
	@warning_ignore("integer_division")
	var half_x: int = tower_size.x / 2
	@warning_ignore("integer_division")
	var half_y: int = tower_size.y / 2

	var start:Vector2i = center_grid - Vector2i(half_x, half_y)

	for dx in range(tower_size.x):
		for dy in range(tower_size.y):
			covers.append(start + Vector2i(dx, dy))
	return covers


