extends "res://script/tower/tower.gd"
## 无人机基地：**负责侦测 + 无人机的生成、回收与调度**
##
## 职责（★ 本次重新设计的核心）：
##   1. 敌人侦测 —— 用基类 tower.gd 的雷达（rader.area_entered → add_target），
##      target 数组就是"射程内的敌人"。can_target() 已经处理了"只有无人机/激光/火箭能打空军"。
##   2. 生成与回收 —— init() 时生成无人机，出售/被摧毁时统一回收。
##   3. **目标分配** —— 每帧看 target 里最近的几个敌人，把无人机分派过去。
##   4. **包围阵位分配** —— 同时打同一个目标时，给它们分配均匀分布的方位角，
##      这样多架会"围成一圈"而不是全挤在一个点。
##
## 无人机自己不做任何侦测/选目标，只执行 assign() 收到的任务（见 drone.gd）。

const DRONE_SCENE := preload("res://scene/drone.tscn")
const DRONE_COUNT := 3          # 无人机数量
## 同一个目标最多派几架去包围（多了也没用，还会互相挡）
const MAX_DRONES_PER_TARGET := 3
## 重新分配目标的间隔（秒）。每帧分配会让无人机一直改主意，反而抖
const ASSIGN_INTERVAL := 0.35

var drones: Array = []

var _assignTimer: float = 0.0
## 目标 -> 已经派给它的无人机数（分配时用来做均衡）
var _claim: Dictionary = {}


func _ready():
	# 雷达形状在代码里补（场景里没配形状），信号也在这里接
	if not raderShape.shape:
		raderShape.shape = CircleShape2D.new()
	rader.area_entered.connect(_onRadarAreaEntered)
	rader.area_exited.connect(_onRadarAreaExited)
	super._ready()


func init():
	super.init()
	_spawnDrones()


func _spawnDrones() -> void:
	_recycleDrones()   # 防止重复 init 时生成两批
	for i in range(DRONE_COUNT):
		var d = DRONE_SCENE.instantiate()
		d.setupDrone(self, i, DRONE_COUNT)
		# 先摆到各自的轨道起点，再入树，避免第一帧从 (0,0) 飞过来
		d.global_position = global_position + Vector2.from_angle(TAU * float(i) / DRONE_COUNT) * 46.0
		Game.addObj(d)
		drones.append(d)


func _recycleDrones() -> void:
	for d in drones:
		if is_instance_valid(d):
			d.queue_free()
	drones.clear()


## 出售 / 被打爆 都走这里回收无人机
## （基类 sell() 调 _on_before_sell；被打爆时 tower.gd 也应调它，见下面的 _release_grid 覆写）
func _onBeforeSell() -> void:
	_recycleDrones()


## 覆写基类的"归还格子"：先回收无人机，再走基类逻辑。
## 这样塔被打爆时无人机不会留在场上乱飞。
func _releaseGrid() -> void:
	_recycleDrones()
	super._releaseGrid()


# ============================================================
# 侦测（雷达信号 → 目标集合，和别的塔一样）
# ============================================================

func _onRadarAreaEntered(area):
	addTarget(area)


func _onRadarAreaExited(area):
	target.erase(area)


# ============================================================
# 目标分配 + 包围阵位
# ============================================================

## 每 ASSIGN_INTERVAL 秒跑一次：
##   ① 清掉失效目标
##   ② 按"离基地由近到远"排个序（先打最靠近基地的，符合塔防直觉）
##   ③ 给每架无人机挑一个目标，并分配包围方位角
func _dispatchDrones() -> void:
	# ① 清理失效 / 飞出射程的目标
	var alive: Array = []
	for e in target:
		if is_instance_valid(e):
			alive.append(e)
	target = alive

	# ② 近的优先
	alive.sort_custom(func(a, b):
		return global_position.distance_squared_to(a.global_position) \
			< global_position.distance_squared_to(b.global_position))

	_claim.clear()

	# ③ 逐架分配
	for i in range(drones.size()):
		var d = drones[i]
		if not is_instance_valid(d):
			continue
		var pick = _pickTargetFor(i, alive)
		if pick == null:
			d.assign(null, 0.0)
			continue
		# 包围方位角：同一目标上的第 n 架分到 2π/n 的位置
		var n: int = int(_claim.get(pick, 0))
		_claim[pick] = n + 1
		var around: int = n % MAX_DRONES_PER_TARGET
		d.assign(pick, TAU * float(around) / float(MAX_DRONES_PER_TARGET))


## 给第 i 架无人机挑目标：
##   · 还没被占满的目标优先（保证火力分散，别 3 架全去打同一个残血怪）
##   · 都满了就退回离基地最近的
func _pickTargetFor(_i: int, alive: Array):
	for e in alive:
		if int(_claim.get(e, 0)) < MAX_DRONES_PER_TARGET:
			return e
	return null


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if drones.is_empty():
		return
	_assignTimer -= delta
	if _assignTimer > 0.0:
		return
	_assignTimer = ASSIGN_INTERVAL
	_dispatchDrones()


# ============================================================
# 生成 / 回收
# ============================================================
