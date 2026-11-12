extends "res://script/enemy/enemy.gd"
## 装甲列车的一节车厢（设计见 feature_design.md §二十五）。
##
## 5 节车厢都是**这一个类型**的独立 `Enemy` 实例，排列与编组由 [TrainConductor] 负责。
## 车厢这边只做三件事：
##
##   1. **头节建编组**：`trainSlot < 0`（场景默认值）就是关卡直接生成的那节，
##      由它创建控制器并补齐其余 4 节；`trainSlot >= 1` 的是控制器生成的跟随节，只报到。
##   2. **减速转发给编组**（§25.7 第 1 条）：整列只有一个速度，任何一节被 EMP 照到
##      就是全列一起慢 —— 各节自算自恢复会让车厢间距漂走，火车看起来散架。
##   3. **死亡上报**（§25.7 第 2 条）：死后请编组收拢一次。
##
## ⚠️ 这里 `extends enemy.gd` 而不是 `boss.gd`，是有意的（§25.7 第 3 条）：
##    `boss.gd::_physics_process` 每帧把头顶血条压掉（顶部大血条才是 boss 的血条），
##    而列车顶部只有**一条**合成血条，"到底哪节在掉血"必须靠头顶血条回答。
##    代价是光环绘制这里自己写一遍（约 15 行），不去改基类影响现有 7 种 boss。
##
## 火力不在这边：每节车厢场景里挂一座 `BaseTurret` 子节点（与实验坦克同一套零件），
## 所以 `enemyInfo` 里 `atk` / `scope` 都是 0，炮塔数值在场景 Inspector 里。

const TrainConductor := preload("res://script/enemy/boss/train_conductor.gd")

## 光环半径（像素）：boss 的身份标识，不是攻击范围（车厢自己不开火）。
const AURA_RADIUS := 88.0
const AURA_PULSE_SPEED := 1.6

## 槽位：< 0 = 头节（关卡生成的那节，负责建编组）；>= 1 = 编组生成的跟随节。
## ⚠️ 只能靠 `spawnEnemy` 的 `props` 注入，不能靠 `enemyInfo`：跟随节与头节是同一个兵种。
@export var trainSlot: int = -1
## 所属编组 id（跟随节由编组在 props 里带进来）
@export var trainGroupId: int = -1

var trainGroup: Node = null
var bossAuraColor: Color = Color(0.62, 0.66, 0.72, 1.0)
var auraPhase: float = 0.0


func _ready() -> void:
	parent = get_parent() as PathFollow2D
	setupEnemyInfo()
	bossAuraColor = Game.enemyInfo.get(enemyType, {}).get("bossAuraColor", bossAuraColor)
	if trainSlot >= 0:
		trainGroup = TrainConductor.groups.get(trainGroupId)
		if trainGroup != null:
			trainGroup.join(self)
		return
	createGroup()


## 头节：把控制器挂到 level 节点下（**不能挂在自己身上**，见 §25.7 架构前提），
## 再让它铺开整列并补齐其余车厢。
func createGroup() -> void:
	var level: Node = Game.map.level if Game.map != null else null
	if level == null:
		push_warning("boss_train: 拿不到 level，本节约为单独存在")
		return
	var group: Node = TrainConductor.new()
	level.add_child(group)
	group.setup(self)
	trainGroup = group


func _physics_process(delta: float) -> void:
	# 基类负责：沿路线推进 + 到达基地的逃脱结算（每节各扣各的血，§25.9 第 4 条）
	super._physics_process(delta)
	if dead:
		return
	auraPhase = fmod(auraPhase + delta * AURA_PULSE_SPEED, TAU)
	queue_redraw()


func _draw() -> void:
	super._draw()
	var pulse: float = 0.5 + 0.5 * sin(auraPhase)
	var fill: Color = Color(bossAuraColor.r, bossAuraColor.g, bossAuraColor.b,
		0.05 + 0.04 * pulse)
	var edge: Color = Color(bossAuraColor.r, bossAuraColor.g, bossAuraColor.b,
		0.35 + 0.20 * pulse)
	draw_circle(Vector2.ZERO, AURA_RADIUS, fill)
	draw_arc(Vector2.ZERO, AURA_RADIUS, 0.0, TAU, 48, edge, 2.0)


## ── 减速：整列共用一张表（§25.7 第 1 条）──
## 不登记到自己身上的话，`enemy.gd` 那张表永远是空的，
## `refreshSpeed()` 也就不会被触发 —— 速度只由编组写。

func addSlow(source: Object, ratio: float) -> void:
	if trainGroup == null or not is_instance_valid(trainGroup):
		super.addSlow(source, ratio)
		return
	trainGroup.teamAddSlow(source, ratio)


func removeSlow(source: Object) -> void:
	if trainGroup == null or not is_instance_valid(trainGroup):
		super.removeSlow(source)
		return
	trainGroup.teamRemoveSlow(source)


## 死亡上报：收拢一次（§25.3）。
## `hurt()` 开头有 `if dead: return` 那道闸，所以这里每节只会走到一次，不用再记旗子。
func hurt(num: int, source = null, damage_type: String = "physical") -> void:
	super.hurt(num, source, damage_type)
	if dead and trainGroup != null and is_instance_valid(trainGroup):
		trainGroup.onCarDied(self)
