extends Node2D

@export var levelId: int
@export var wave: int
@export var health: int
@export var money: int

## 本关敌人生成间隔（秒），来自关卡配置的 spawnInterval，不写就用 DEFAULT_SPAWN_INTERVAL。
## 这是**兜底值**：每条 enemySpawner 记录还能用 "delay" 单独覆盖（见 _next_spawn_delay）。
## 教程关被当成"大量敌人"压力测试场（两百多个敌人），必须调快。
const DEFAULT_SPAWN_INTERVAL := 1.0

## 记录级间隔的下限。写 0 或负数会让整波瞬间叠在一起，所以卡一个最小值。
const MIN_SPAWN_DELAY := 0.05

## 本关的兜底生成间隔（_ready 时从关卡配置读入）
var _spawn_interval: float = DEFAULT_SPAWN_INTERVAL

@onready var waveTimer = $waveTimer
@onready var spawnerTimer = $spawnerTimer
@onready var towerShadow = $towerShadow

## 本关的行军路线。关卡场景里**按摆放顺序**摆几个 Path2D 就有几条路线：
## 第 1 个 Path2D = 路线1，第 2 个 = 路线2 ……
## 目前所有关卡都只摆了一个（单路线）；要加多路线不用改这里，场景里多摆一个 Path2D 就行。
## map.gd 的 _is_multi_route_level() 也是按「Path2D 数量 > 1」判断的。
var routes: Array[Path2D] = []


var currWave = 0  #当前波次
var enemyList = []
var currentSpawner = [] # 当前生产列表

var allowArea: Array[Vector2i] = [] # 允许放置塔的区域
var occupiedArea: Array[Vector2i] = [] # 已占用的区域

## ── 行进偏移（v_offset）：让同一路线上的敌人不再叠在一起 ──
##
## 传送带表面只有 37px 宽（sprite/tile/belt_we.png 的 y=14..49，上下还有边轨），
## 而敌人有 25~34px 宽，所以**偏移量必须小**，超过 ±12 就会压到边轨上。
## 因此这里不是一个"随便挑个 ±32"，而是按敌人宽度分档：
##   · 轻型(≈25~28px)：能并排两条道 → ±9
##   · 中型(≈31~33px)：稍微错开   → ±6
##   · 重型(≈34~44px)：几乎占满   → ±3（只求别完全同心）
##
## 分道规则：
##   · 不同兵种的**主方向**不同（偶数号走一侧、奇数号走另一侧），
##     所以"同一时刻刷出来的不同兵种"天然落在两侧，不会叠在一起；
##   · 同一兵种连续刷出时，在它自己的 ±lane 之间**交替**（_spawn_lane 计数器）。
##
## 关卡记录里写了 'offset' 就用手写的值（多路线关卡常这么用来贴某条带子），
## 没写才走上面的自动分道。
const AUTO_OFFSET_LANES := [-1.0, 1.0]
## 敌人类型 -> 分道幅度（像素）。没列到的类型用 MEDIUM。
##
## ⚠️ 幅度取很小（±5）是有原因的：传送带表面只有 37px 宽，
##    而装甲坦克/攻击直升机有 44~48px —— 它们本来就略微探出带面。
##    幅度再放大就会明显压到上下边轨上，反而更难看。
##    ±5 的作用是"别完全同心"，让一列敌人看起来是错开走的，不是摞在一起。
const OFFSET_HALF_WIDTH := {
	Game.enemyType.miniTank: 5.0,
	Game.enemyType.assaultBuggy: 5.0,
	Game.enemyType.scoutDrone: 5.0,
	Game.enemyType.mediumTank: 4.0,
	Game.enemyType.medic: 4.0,
	Game.enemyType.suicideTruck: 4.0,
	Game.enemyType.heavyTank: 3.0,
	Game.enemyType.armoredTank: 3.0,
	Game.enemyType.missileTruck: 3.0,
	Game.enemyType.attackHelicopter: 3.0,
}
const OFFSET_HALF_DEFAULT := 4.0

## 同一兵种内的交替计数器：类型 -> 已经刷了几个
var _spawn_lane: Dictionary = {}

func _ready() -> void:
	Game.selectTower.connect(selectTower)
	_collect_routes()
	for i in StageData.allStage:
		if levelId == i.get("id"):
			wave = i.get("wave")
			health = i.get("health")
			money = i.get("money")
			enemyList = i.get("enemySpawner")
			# 生成间隔：关卡配置可覆盖（教程关要放大量敌人，必须调快）
			var interval := float(i.get("spawnInterval", DEFAULT_SPAWN_INTERVAL))
			if interval > 0.0:
				_spawn_interval = interval
				spawnerTimer.wait_time = interval
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
	towerShadow.scope=temp.scope
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
		# 本波第一拍也要按队首记录的 delay 走，不能沿用上一波残留的 wait_time
		spawnerTimer.wait_time = _next_spawn_delay()
		spawnerTimer.start()
	if currWave >= wave:
		Game.lastWave.emit()
		return
	waveTimer.start()

## 一次 tick **只生成一个敌人**，生成完再按"下一个敌人的兵种"设置下次间隔。
##
## ⚠️ 旧实现是 `for spawn_info in currentSpawner.duplicate()` —— 一次 tick 把
##    **所有**记录都刷出来。两条记录写同一个 time，敌人就同一帧出现在同一个点上，
##    叠成一坨往前走。而且 spawnerTimer.wait_time 是固定值，
##    没办法让"不同兵种用不同间隔"。
##
## 现在的规则：每次只取队首记录生成 1 个；该记录 number 减到 0 就出队。
## 下一拍的间隔**按下一个敌人的兵种查表**（StageData.ENEMY_SPAWN_DELAY）。
##
## 间隔统一从那张表拿，所以关卡配置里**不用再逐条写 delay** ——
## 全工程 16 个关卡、五百多条记录自动一致。
## 关卡想整体放慢/加快，用 'spawnInterval'（表里没配的兵种才会用到它）。
func _on_spawner_timer_timeout():
	# 清掉已经生成完的记录
	while currentSpawner.size() > 0 and int(currentSpawner[0].get("number", 0)) <= 0:
		currentSpawner.pop_front()

	if currentSpawner.is_empty():
		return

	var spawn_info: Dictionary = currentSpawner[0]
	_spawn_enemy(spawn_info)
	spawn_info["number"] = int(spawn_info.get("number", 0)) - 1
	if int(spawn_info["number"]) <= 0:
		currentSpawner.pop_front()

	# 还有下一个就排下一拍；间隔按"下一个敌人所属记录"的 delay 走
	if currentSpawner.is_empty():
		return
	spawnerTimer.wait_time = _next_spawn_delay()
	spawnerTimer.start()


## 下一个敌人的生成间隔：按**队首记录的敌人类型**查 StageData.ENEMY_SPAWN_DELAY。
##
## 查表拿不到的类型，回落到本关兜底间隔 _spawn_interval（教程关 1.0，
## 其它关卡走 DEFAULT_SPAWN_INTERVAL）—— 保证永远不会出现"漏配 → 瞬间刷一堆"。
func _next_spawn_delay() -> float:
	if currentSpawner.is_empty():
		return _spawn_interval
	var enemy_type = currentSpawner[0].get("type", null)
	if enemy_type == null:
		return maxf(_spawn_interval, MIN_SPAWN_DELAY)
	return maxf(StageData.get_spawn_delay(enemy_type), MIN_SPAWN_DELAY)




## 算这次生成该给多大偏移。
## 返回 0 表示贴中线（理论上不会 —— 只要配了分道幅度就一定有侧向位移）。
func _resolve_offset(spawn_info: Dictionary) -> float:
	# 手写 offset 优先
	if spawn_info.has("offset"):
		return float(spawn_info.get("offset", 0.0))
	var t = spawn_info.get("type", null)
	if t == null:
		return 0.0
	var half: float = float(OFFSET_HALF_WIDTH.get(t, OFFSET_HALF_DEFAULT))
	# 同一兵种内交替左右；不同兵种的主方向由类型序号决定，避免同刻叠一起
	var n: int = int(_spawn_lane.get(t, 0))
	_spawn_lane[t] = n + 1
	var side: float = AUTO_OFFSET_LANES[n % AUTO_OFFSET_LANES.size()]
	# 再叠一个"兵种序号"的奇偶，让不同兵种主方向错开
	var type_parity: float = 1.0 if (int(t) % 2) == 0 else -1.0
	return half * side * type_parity


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
	# 偏移：让同一路线上的敌人散开、不叠在一起（详见 _resolve_offset）。
	# 用 PathFollow2D 的 v_offset 实现，所以它是**固定侧向位移**、跟着曲线拐弯，
	# 不是随机抖动。必须在 add_child 之后设 —— PathFollow2D 要拿到父级 Path2D
	# 才会重算位置。
	# 方向约定：正 = 行进方向的右侧，靠敌人根节点 rotates = true（默认）得来；
	# 以后若把某个敌人的 PathFollow2D 改成 rotates = false，h/v_offset 会退化成
	# 世界坐标偏移，那时得改用别的做法。
	var offset := _resolve_offset(spawn_info)
	var follower := enemy_instance as PathFollow2D
	if follower != null:
		follower.v_offset = offset
	elif not is_zero_approx(offset):
		push_warning("敌人场景根节点不是 PathFollow2D，'offset' 无法生效: " + str(scene.resource_path))
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
