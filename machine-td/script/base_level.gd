extends Node2D

@export var levelId: int
@export var wave: int
@export var health: int
@export var money: int

@onready var waveTimer = $waveTimer
@onready var spawnerTimer = $spawnerTimer
@onready var towerShadow = $towerShadow

## 本关的行军路线。关卡场景里**按摆放顺序**摆几个 Path2D 就有几条路线：
## 第 1 个 Path2D = 路线1，第 2 个 = 路线2 ……
## 目前所有关卡都只摆了一个（单路线）；要加多路线不用改这里，场景里多摆一个 Path2D 就行。
## map.gd 的 _is_multi_route_level() 也是按「Path2D 数量 > 1」判断的。
var routes: Array[Path2D] = []


var currWave = 0
var enemyList = []
var currentSpawner = [] # 当前生产列表

var allowArea: Array[Vector2i] = [] # 允许放置塔的区域
var occupiedArea: Array[Vector2i] = [] # 已占用的区域


func _ready() -> void:
	Game.selectTower.connect(selectTower)
	_collect_routes()
	for i in StageData.allStage:
		if levelId == i.get("id"):
			wave = i.get("wave")
			health = i.get("health")
			money = i.get("money")
			enemyList = i.get("enemySpawner")
			# 配置里声明的路线数和场景里实际摆的 Path2D 数量应当一致，不一致给个提示
			var declared := int(i.get("routes", 1))
			if declared != routes.size():
				push_warning("关卡 %d 声明 %d 条路线，场景里实际摆了 %d 个 Path2D" % [levelId, declared, routes.size()])
			break
	# 可建造区：关卡里摆的 placeableArea 实例（子节点 _ready 已先跑完，位置对齐过了）
	_collect_allow_area()

# 收集本关所有路线：场景里的 Path2D 子节点，按摆放顺序。
# 约定第 1 个就是「路线1」—— 所以关卡配置里不写 route 的敌人默认走它。
func _collect_routes() -> void:
	routes.clear()
	for child in get_children():
		if child is Path2D:
			routes.append(child)

# 取第 route_no 条路线。route_no 从 1 开始（和关卡配置里的写法一致）。
# 越界时回落到最后一条，路线一条都没有时返回 null ——
# 不让一个手滑写错的数字直接把敌人变成"不出现"。
func get_route(route_no: int) -> Path2D:
	if routes.is_empty():
		return null
	return routes[clampi(route_no - 1, 0, routes.size() - 1)]

func get_route_count() -> int:
	return routes.size()

# 把关卡里所有 placeableArea 实例换算成格子坐标填进 allowArea。
# 老关卡仍可在自己脚本里手写 allowArea，两者会合并。
func _collect_allow_area() -> void:
	for node in get_tree().get_nodes_in_group("placeableArea"):
		if not node.has_method("get_grid"):
			continue
		var grid: Vector2i = node.get_grid()
		if grid not in allowArea:
			allowArea.append(grid)

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

# 开始生成敌人
func start():
	waveTimer.start()

func _on_wave_timer_timeout():
	if currentSpawner.size() > 0:
		waveTimer.start()
		return
	if get_tree().get_nodes_in_group("enemy").size() > 0:
		waveTimer.start()
		return

	currWave += 1
	Game.refreshData.emit({'wave': currWave})
	for spawn_info in enemyList:
		if int(spawn_info.get("time", 0)) == currWave:
			currentSpawner.append(spawn_info.duplicate())

	if currentSpawner.size() > 0:
		spawnerTimer.start()
	if currWave >= wave:
		Game.lastWave.emit()
		return
	waveTimer.start()

func _on_spawner_timer_timeout():
	for spawn_info in currentSpawner.duplicate():
		if int(spawn_info.get("number", 0)) <= 0:
			currentSpawner.erase(spawn_info)
			continue
		_spawn_enemy(spawn_info)
		spawn_info["number"] -= 1

	if currentSpawner.size() > 0:
		spawnerTimer.start()

func _spawn_enemy(spawn_info: Dictionary):
	# 'route' 不写就是路线1；写 2、3 …… 就从别的路线出发
	var route := get_route(int(spawn_info.get("route", 1)))
	if route == null or route.curve == null:
		push_error("关卡缺少 Path2D 或路径曲线")
		return
	var scene = StageData.enemyScenes.get(spawn_info.get("type"))
	if scene == null:
		push_error("未配置敌人场景: type=" + str(spawn_info.get("type")))
		return
	var enemy_instance = scene.instantiate()
	route.add_child(enemy_instance)
	var enemy_node = enemy_instance.get_node_or_null("enemy")
	if enemy_node == null:
		push_error("敌人场景缺少 enemy 节点: " + str(scene.resource_path))
		enemy_instance.queue_free()
		return
	enemy_node.points = route.curve.get_baked_points()

# 获取塔占用的网格
func getTowerCoverGrid(center_grid: Vector2i, tower_size: Vector2i) -> Array[Vector2i]:
	var covers: Array[Vector2i] = []
	# 偏移：从中心向左上角偏移一半网格
	@warning_ignore("integer_division")
	var half_x: int = tower_size.x / 2
	@warning_ignore("integer_division")
	var half_y: int = tower_size.y / 2

	var startGrid: Vector2i = center_grid - Vector2i(half_x, half_y)

	for dx in range(tower_size.x):
		for dy in range(tower_size.y):
			covers.append(startGrid + Vector2i(dx, dy))
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
