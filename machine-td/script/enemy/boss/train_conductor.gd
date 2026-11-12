extends Node2D
## 装甲列车的编组控制器（设计见 feature_design.md §二十五）。
##
## 一条列车 = 5 个独立的 `Enemy` 实例（车厢），这个控制器负责让它们**像一列火车**：
##   · 铺开：头节从 `(CAR_COUNT-1) × CAR_SPACING` 处入场，5 节全在路线内
##   · 槽位：以"当前最前面那节"为锚点，后面的依次排在 `anchor - i × CAR_SPACING`
##   · 压缩：**只在车厢死亡的那一帧**改写一次槽位（§25.7 第 2 条）
##   · 共享减速：全队只有一个速度（§25.7 第 1 条）
##
## ⚠️ 本节点挂在 **level 节点**下，不挂在任何车厢上 —— leader 车厢死后编组还要继续存在，
##    挂在车厢上会跟着一起被释放（§25.7 的架构前提）。
##
## M1~M2 只做上面这些。合成血条（M3）、车厢3 宝石与全灭爆炸（M4）另加。

## 一节车厢沿路线占多少像素：贴图宽 × scale + 连接处（占位美术阶段取 72）。
## 换正式美术时**只改这一个数**，槽位、起点铺开、压缩量都跟着走。
const CAR_COUNT := 5
const CAR_SPACING := 72.0

## 编组登记表：`groupId -> conductor`。
## 车厢是通过 `level.spawnEnemy()` 生成的，拿不到构造时的引用，只能靠 id 回来找组织。
static var groups: Dictionary = {}

## 车厢列表，**从最前面那节开始排**（index 0 = 当前 leader）。
var cars: Array[Enemy] = []
var groupId: int = 0
var route: Path2D = null
var routeLength: float = 0.0

## ── 全队共享减速表（§25.7 第 1 条）──
## 语义与 `enemy.gd` 那张表一致：来源 -> 比例，**取最强一条生效**（不连乘）。
## 差别在于这里记的是"整列"的：任何一节进 EMP 圈，整列一起慢。
var teamSlowSources: Dictionary = {}
var teamBaseSpeed: int = 0
## 二阶段免疫减速用（M4），先留开关：为真时整列不受任何减速
var immuneSlow: bool = false

static var nextGroupId: int = 0


## 由头节在 `_ready()` 里调用：接管这一列，并补齐其余车厢。
func setup(head: Enemy) -> void:
	nextGroupId += 1
	groupId = nextGroupId
	groups[groupId] = self
	var wrapper: PathFollow2D = head.parent
	route = wrapper.get_parent() as Path2D
	if route == null or route.curve == null:
		push_warning("train_conductor: 头节不在 Path2D 下，列车退化成单节")
		return
	routeLength = route.curve.get_baked_length()
	teamBaseSpeed = head.baseSpeed
	# ⚠️ 头节也必须强制归到中心线：关卡的 `resolveOffset()` 会给没写 offset 的兵种
	#    自动分配左右车道，于是头车偏 4px、后 4 节在中心线上 —— 列车变成歪的一排。
	wrapper.v_offset = 0.0
	cars.append(head)
	# 起点铺开：头节先走到"整列正好全在路线里"的位置。
	# 不铺开的话后 4 节的 progress 是负数，会全堆在起点叠成一坨（§25.2）。
	wrapper.progress = minf(float(CAR_COUNT - 1) * CAR_SPACING, routeLength - 1.0)
	for i in range(1, CAR_COUNT):
		spawnCar(head, i)
	applySlots()


## 在自己身后再生成一节车厢。
## `offset` 必须显式写 0：`resolveOffset()` 不给值就会按兵种自动分配左右车道，
## 一列车就成了两条平行轨道，车厢前后错开 —— 那不是火车。
func spawnCar(head: Enemy, slot: int) -> void:
	var level: Node = Game.map.level if Game.map != null else null
	if level == null:
		push_warning("train_conductor: 拿不到 level，无法补齐车厢")
		return
	var back: float = float(slot) * CAR_SPACING
	level.call("spawnEnemy", {
		"type": head.enemyType,
		"route": routeIndex(),
		"offset": 0.0,
		"progress": maxf(0.0, float(head.parent.progress) - back),
		"props": {"trainSlot": slot, "trainGroupId": groupId, "silentBoss": true},
	})


func routeIndex() -> int:
	var level: Node = Game.map.level if Game.map != null else null
	if level == null or not ("routes" in level):
		return 1
	var i: int = (level.routes as Array).find(route)
	return i + 1 if i >= 0 else 1


## 车厢生成后自己来报到（`boss_train.gd::_ready()`）。
func join(car: Enemy) -> void:
	if car == null or cars.has(car):
		return
	cars.append(car)
	sortByProgress()


## 按 progress 从大到小重排：index 0 永远是**最接近基地**的那节 = 当前 leader。
## 靠插入顺序不可靠（车厢是同帧生成的，压缩后顺序也会变）。
func sortByProgress() -> void:
	cars.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.parent.progress > b.parent.progress)


## 槽位改写：以 leader 为锚点，后面的依次排到 `anchor - i × CAR_SPACING`。
##
## 这一条同时实现了 §25.3 的"收拢"：
##   · 死的是 leader → 新的 cars[0] 就是原来那节第 2 车厢，锚点没变，**整列不跳**
##   · 死的是中间那节 → 它后面的每节各前进一格，前面的不动
##   · 死的是尾车 → 后面的没车厢，什么都不动（"先拆尾车最安全"的由来）
func applySlots() -> void:
	pruneDead()
	if cars.size() < 2:
		return
	var anchor: float = float(cars[0].parent.progress)
	for i in range(1, cars.size()):
		var follower: PathFollow2D = cars[i].parent
		follower.progress = maxf(0.0, anchor - float(i) * CAR_SPACING)


## 车厢死亡（`hurt()` 打死那一帧）：移出编组 + 收拢 + 全灭时释放自己。
func onCarDied(car: Enemy) -> void:
	if not cars.has(car):
		return
	cars.erase(car)
	# M4 在这里播"最后一节爆炸"（§25.6），并结算车厢3 的宝石（§25.5）
	if cars.is_empty():
		queue_free()
		return
	applySlots()


func isRearmost(car: Enemy) -> bool:
	return not cars.is_empty() and cars[cars.size() - 1] == car


## ── 减速：车厢把 addSlow / removeSlow 原样转发到这里 ──

func teamAddSlow(source: Object, ratio: float) -> void:
	if source == null:
		return
	var clamped: float = clampf(ratio, 0.0, Enemy.MAX_SLOW_RATIO)
	if clamped <= 0.0:
		teamRemoveSlow(source)
		return
	teamSlowSources[source] = clamped
	refreshTeamSpeed()


func teamRemoveSlow(source: Object) -> void:
	if source == null or not teamSlowSources.has(source):
		return
	teamSlowSources.erase(source)
	refreshTeamSpeed()


## 取最强一条减速算出**全队唯一**的速度，再写回每一节。
##
## ⚠️ 为什么必须写回每一节而不是只改 leader：车厢自己也在 `_physics_process` 里
##    `progress += speed * delta`（保留各节独立的逃脱结算，见 §25.9 第 4 条）。
##    只要速度不同，间距就会被拉长或挤叠 —— 视觉直接变成"火车散架"，机制也就废了。
func refreshTeamSpeed() -> void:
	if teamBaseSpeed <= 0:
		return
	var strongest: float = 0.0
	var stale: Array = []
	for src in teamSlowSources:
		# 塔被卖掉 / 场景卸载：清掉，别越攒越大
		if not is_instance_valid(src):
			stale.append(src)
			continue
		strongest = maxf(strongest, float(teamSlowSources[src]))
	for key in stale:
		teamSlowSources.erase(key)
	if immuneSlow:
		strongest = 0.0
	var teamSpeed: int = maxi(1, int(round(float(teamBaseSpeed) * (1.0 - strongest))))
	for car in cars:
		if is_instance_valid(car):
			car.speed = teamSpeed


## 清掉已经失效的条目：测试场景「清空 Boss」是直接 `freeSelf()`，不走 `hurt()`，
## 那种路径不会有 onCarDied，只能靠这里兜一手，否则编组会攥着已释放的车厢不放。
func pruneDead() -> void:
	var alive: Array[Enemy] = []
	for car in cars:
		if is_instance_valid(car) and not car.dead:
			alive.append(car)
	cars = alive


func _process(_delta: float) -> void:
	if cars.is_empty():
		return
	pruneDead()
	if cars.is_empty():
		queue_free()


func _exit_tree() -> void:
	if groups.get(groupId) == self:
		groups.erase(groupId)
