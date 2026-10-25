extends Area2D

class_name Enemy

@export var hp = 100 # 血量
@export var speed: int # 移动速度
@export var reward = 0 # 奖励
@export var lossPoints = 1 # 损失点数
@export var rewardExp = 2 # 经验值
@export var gemReward: int = 0 # 击败掉落的宝石数（0=不掉 / 1 / 2，数值来自 Game.enemyInfo）
@export var gemRewardChance: float = 1.0 # 掉落的概率(0~1)；1.0 = 必掉，0.5 = 约一半才掉
@export var enemyType: Game.enemyType = Game.enemyType.miniTank # 敌人类型
@export var armor: float = 0.0 # 物理伤害减免百分比（0~1，能量伤害无视）
@export var flying: bool = false # 空中单位（仅无人机/激光塔可命中）
@export var atk: int = 0 # 攻击力（对抗型有效，推进型为0）
@export var shootDelay: float = 1.0 # 开火间隔秒（对抗型有效）
@export var radarScope: float = 0.0 # 雷达半径(像素)：对抗/支援型的攻击或支援范围，0 表示不参战
## 点击这个敌人时是否画出攻击范围（见 feature_design.md §9.3）。
## ⚠️ **不能只看 `atk > 0`**：维修车 atk=20 但是治疗友军、自爆车 atk=80 但是撞击自爆，
##    两者都不远程打塔。所以这个开关由 Game.enemyInfo 显式声明，这里只负责读。
@export var showsRange: bool = false
var maxHp: int = 100 # 最大血量（初始化时由 hp 同步）

var vec = Vector2.ZERO
var target = [] # 目标
var points = [] # 路径点
var pointIndex = 0
var dead = false # 是否死亡
## 被点击选中（选中时自己画攻击范围圈，见 _draw）。
## ⚠️ 为什么圈由**敌人自己画**、而不是在 map.gd 里画：
##    画在 map 上时，敌人一旦 free，map 里那个"选中敌人"就变无效，
##    `_physics_process` 里的重绘条件变假 → 再没人调 _draw → **上一帧的圈永远留在画布上**
##    （玩家实测：敌人被消灭后地图上留一个红圈）。
##    与防御塔同一套做法（tower.gd 也是自己画），敌人没了圈自然就没了。
var selected = false
## 雷达扫描线角度（选中时那条旋转的亮线，与防御塔的观感一致）
var radarSweepAngle: float = 0.0
var rotationSpeed = 10
var canShot = true

## ── 减速状态（EMP 塔用）──
## 原始移动速度：`speed` 会被减速改写，这里永远保存"没被减速时"的值。
## 由 setupEnemyInfo() 在读完 enemyInfo 之后写入。
var baseSpeed: int = 0
## 当前覆盖自己的减速来源：来源节点 -> 减速比例(0~1)。
##
## ⚠️ 为什么要在敌人身上记，而不是让每座 EMP 各改一次 `speed`：
##    旧实现是 `speed *= (1 - ratio)`（进入时乘、离开时除回去）。
##    两座 EMP 射程重叠时，先乘 A 再乘 B，离开时按各自比例除 —— 
##    只要两座塔的 atk 不同（或整数取整累积误差），除回来就对不上原值，
##    速度会漂移到一个既不是原速、也不是任一减速值的结果。
##    现在改成"记录所有来源、取**最强的一条**生效"，多座塔重叠时只受最强的那座限制，
##    离开一座自动回落到次强的那座，全部离开则精确恢复 baseSpeed。
var slowSources: Dictionary = {}

var parent: PathFollow2D

const ENEMY_BULLET: PackedScene = preload("res://scene/bullet/enemy_bullet.tscn")
## 回血特效（绿色 + 号，向上飘后淡出）。见 addHp()。
const HEAL_FX := "res://scene/fx/heal_particles.tscn"
## 雷达扫描线转速（弧度/秒）。与 tower.gd 的 RADAR_SCAN_SPEED 保持一致 ——
## 两种圈看起来才是同一个东西，而不是"我方一种、敌方另一种"。
const RADAR_SCAN_SPEED := 1.8

## 减速比例上限。留 10% 速度是为了避免"完全静止后敌人永远卡在同一格"，
## 同时防止将来把 EMP 的 atk 调高后出现速度 0 的僵局。
const MAX_SLOW_RATIO: float = 0.9

@onready var base = $base
## ⚠️ 必须用 get_node_or_null：直升机/无人机这类**没有 turret 节点**，
##    而 `$turret` 取不到节点时会直接报错（不是返回 null）。
##    更早的坑：attackHelicopter.gd 里无条件访问 turret.global_position，
##    它一开火就会崩 —— 现在统一走 getMuzzlePosition()，没有炮塔就退回机身前方。
@onready var turret = get_node_or_null("turret")
## 炮口标记（基场景里挂在 turret 下，所以跟着炮管一起转）。位置由 `muzzleOffset` 在
## setupEnemyInfo() 里写入；同样用 get_node_or_null 兜底，缺了也不会报错。
## ⚠️ 成员名不叫 `muzzle`：attackTower() 和几个子类里都有 `var muzzle: Vector2` 这个
##    局部变量，重名会触发 SHADOWED_VARIABLE 警告。
@onready var muzzleMarker: Marker2D = get_node_or_null("turret/Muzzle")
## 血条。**必须是敌人的子节点**（见 _processLifeBar 的注释：放 CanvasLayer 下会跑到屏幕外）。
@onready var lifeBar = get_node_or_null("LifeBar")
@onready var delayTimer = $Delay
@onready var radar = $radar
@onready var radarShape = $radar/shape

## 炮口到**瞄准轴心**的像素距离 —— 由代码写进 `turret/Muzzle`，**不要**去场景里改 Marker2D。
##
## ⚠️ 为什么放代码里（与防御塔 tower.gd 是同一个坑）：基场景 enemy.tscn 里的 Marker2D 是 (0,0)，
##    子场景就算覆盖了，只要在编辑器里一保存那个子场景，覆盖就**会被丢掉** ——
##    防御塔那边特斯拉已经丢过一次（表现是"闪电从塔中心发出来"）。
##    写成导出变量，值跟着脚本走，谁也覆盖不掉。
##
## 取值分两种（都从素材量，单位=像素）：
##   · 有**可见**炮塔的敌人（四种坦克）：炮塔贴图的**炮口** → 贴图**轴心**的距离
##   · 没有炮塔的敌人（直升机 / 飞机 / 导弹车 / 突击车）：**机身最前端** → **机身中心**的距离
## 注意炮塔贴图的 `AnimatedSprite2D.offset` 只做**视觉**平移、不带动子节点，
## 所以这里必须显式写，不能指望它把 Marker2D 一起带走。
@export var muzzleOffset: float = 0.0

## 开火后坐距离（像素，沿炮管反方向）。默认 5 —— 与防御塔 "fire" 动画的推力一致。
## 想让某个敌人后坐更猛/更轻，在它的场景里覆盖这个值就行（远程导弹车之类的可以调大）。
## 详见 [method playTurretRecoil]。
@export var turretRecoil: float = 5.0
const LIFE_BAR_OFFSET := Vector2(0.0, -50.0)
## 被击中后血条亮多久（秒）。数值沿用血条场景里 Timer 原本的 3.0，改这里就够。
## 选中敌人期间血条一律不显示（见 setSelected），选中前被打过的话，
## 取消选中时若还没到点会重新亮起来。
const HIT_SHOW_SECONDS := 3.0

## ── 开火后坐（炮塔贴图往后一顿再弹回）──
## 防御塔是在 player 的 "fire" 动画里把 `turret:offset` 从 (0,0) 推到 (-5,0) 再弹回、
## 全长 0.2s（见 scene/tower/machineGunTower.tscn 的 Animation_k8n1u）；敌人一辆车一个场景，
## 挨个配 AnimationPlayer 太啰嗦，这里用代码补间做**同一件事** ——
## 于是所有带炮塔的敌人**默认**就有后坐，新加敌人也不用管。
##
## 只动**贴图的 offset**（纯视觉、不带动子节点）：炮口 Marker2D 与命中判定都不受影响，
## 这一点与防御塔动画的写法一致。
## 没有炮塔 / 炮塔被隐藏的敌人（无人机、直升机、战斗飞机、导弹车、突击车）自动跳过。
##
## ⚠️ 自己写 `fire()` 的敌人（中型坦克这类）不会走 [method attackTower]，
##    要在开火那次调用里自己补一句 `playTurretRecoil()`。
const RECOIL_BACK_TIME: float = 0.1
const RECOIL_RETURN_TIME: float = 0.1

## ── 被击中的"变亮"反馈 ──
## 材质挂在 scene/enemy/enemy.tscn 的 base / turret 上，所有敌人共用（派生场景继承得到）。
## 这里只负责把 shader 的 flash 参数从 1 补间到 0。
const HIT_FLASH_TIME := 0.10
var hitFlashTween: Tween

var recoilTween: Tween
var turretOffsetBase: Vector2 = Vector2.ZERO
var turretOffsetCached: bool = false


## 开火点：有**可见**炮塔就用 `turret/Muzzle`（跟着炮管转 ⇒ 正好在炮口），
## 没炮塔（直升机 / 飞机 / 卡车）就把炮口算在机身正前方（跟着机头转）。
## 两条路径都返回 Vector2，调用方不用再判空。
##
## ⚠️ 判断条件是 `turret.visible`，不是 `turret != null`：
##    基场景 scene/enemy/enemy.tscn **自带 turret 节点**，派生场景里删不掉它
##    （删了会退回继承基场景的那个），所以"这个敌人没有炮塔"是靠
##    `visible = false` 表达的。只看 null 会把隐藏的炮塔位置当成枪口。
func getMuzzlePosition() -> Vector2:
	if turret != null and is_instance_valid(turret) and turret.visible and muzzleMarker != null:
		return muzzleMarker.global_position
	if base != null and is_instance_valid(base):
		return base.global_position + Vector2(muzzleOffset, 0.0).rotated(base.global_rotation)
	return global_position

# 从 Game.enemyInfo 读取本敌人的基础数值进行初始化
# 由各敌人子类在 _ready() 中调用（此时 @onready 节点已就绪）
func setupEnemyInfo():
	var info = Game.enemyInfo.get(enemyType)
	if info == null:
		return
	hp = int(info.get("hp", hp))
	maxHp = hp
	speed = int(info.get("speed", speed))
	# 战斗模式的**移动速度**倍数（feature_design.md §十七）。
	# ⚠️ 模式不改出怪间隔，只改这里 —— 间隔一缩敌人会在路径上叠成一团。
	# 放在记 baseSpeed **之前**：EMP 的减速是从"模式调整后的原速"往下减的，
	# 否则蜂群的 ×1.2 会被 EMP 的恢复逻辑抹掉。
	if not is_equal_approx(Game.modeSpeedScale, 1.0):
		speed = maxi(1, int(round(float(speed) * Game.modeSpeedScale)))
	# 记录原速：之后 EMP 塔减速只改 `speed`，恢复时永远以这个值为准，
	# 不会因为"乘了两次、除回一次"而漂移。
	baseSpeed = speed
	reward = int(info.get("reward", reward))
	lossPoints = int(info.get("lossPoints", lossPoints))
	rewardExp = int(info.get("rewardExp", rewardExp))
	gemReward = int(info.get("gemReward", gemReward))
	gemRewardChance = float(info.get("gemRewardChance", gemRewardChance))
	armor = float(info.get("armor", armor))
	flying = bool(info.get("flying", flying))
	atk = int(info.get("atk", atk))
	showsRange = bool(info.get("showsRange", showsRange))
	# 难度缩放：**两套独立来源相乘**
	#   · Game.enemyScale / enemyAtkScale —— 无尽模式按波次上涨（普通关卡恒为 1.0）
	#   · Game.modeHpScale / modeAtkScale —— 战斗模式（feature_design.md §十七）
	# 千万不要合并成一个变量：无尽模式每波会重写前者，合并会让两套互相覆盖。
	var hpScale: float = Game.enemyScale * Game.modeHpScale
	if not is_equal_approx(hpScale, 1.0):
		hp = maxi(1, int(ceil(float(hp) * hpScale)))
		maxHp = hp
	var atkScale: float = Game.enemyAtkScale * Game.modeAtkScale
	if not is_equal_approx(atkScale, 1.0):
		atk = int(ceil(float(atk) * atkScale))
	# 击杀收益 / 塔经验按"总血量"折算（§17.5）：蜂群数量翻倍、每杀收益减半，
	# 保证每点血量给的钱与经验恒定 —— 否则击杀数翻倍会让金币和塔等级也翻倍，
	# 「困难模式」反而变成最容易的模式。
	if not is_equal_approx(Game.modeRewardScale, 1.0):
		reward = maxi(0, int(round(float(reward) * Game.modeRewardScale)))
	if not is_equal_approx(Game.modeExpScale, 1.0):
		rewardExp = maxi(0, int(round(float(rewardExp) * Game.modeExpScale)))
	shootDelay = float(info.get("shootDelay", shootDelay))
	radarScope = float(info.get("scope", radarScope))
	if shootDelay > 0:
		delayTimer.wait_time = shootDelay
	if lifeBar:
		lifeBar.setMax(hp)
		lifeBar.setValue(hp)
	# 炮口标记的位置也在这里写（理由见 muzzleOffset 的注释：场景里改会被编辑器丢掉）
	if muzzleMarker != null:
		muzzleMarker.position = Vector2(muzzleOffset, 0.0)
	applyRadarScope()


# 按 radarScope 同步雷达碰撞体半径（数值唯一来源是 Game.enemyInfo 的 scope 字段）
# 推进型(radarScope <= 0)不参战，直接关闭雷达侦测，避免空转物理检测
# 场景里没有配置 radar/shape 形状的敌人（自爆车、侦察无人机）在这里按需补一个圆形碰撞体
func applyRadarScope() -> void:
	if radar == null or radarShape == null:
		return
	if radarScope <= 0.0:
		radar.monitoring = false
		return
	var circle: CircleShape2D = radarShape.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		radarShape.shape = circle
	circle.radius = radarScope
	radar.monitoring = true


## ── 减速（EMP 塔）──
##
## 调用约定：塔只在"进入雷达 / 离开雷达 / 自己被卖掉"这三个时机调一次，
## 敌人自己负责把多座塔的影响合并成**一条**结果。
## 这样塔不需要知道别的塔存在，也不需要保存"我把它减了多少"（那个数字会因为叠加而失去意义）。

## 登记一个减速来源。ratio 是减速比例（0.3 = 移动速度 -30%）。
## 同一来源重复登记会覆盖（例如以后塔升级改了 atk）。
func addSlow(source: Object, ratio: float) -> void:
	if source == null:
		return
	var clamped: float = clampf(ratio, 0.0, MAX_SLOW_RATIO)
	if clamped <= 0.0:
		removeSlow(source)
		return
	if baseSpeed <= 0:
		baseSpeed = speed
	slowSources[source] = clamped
	refreshSpeed()


## 注销一个减速来源（敌人离开该塔雷达，或塔被卖掉/销毁）。
func removeSlow(source: Object) -> void:
	if source == null or not slowSources.has(source):
		return
	slowSources.erase(source)
	refreshSpeed()


## 按"最强的一条减速"重算速度。
##
## ⚠️ 取最大值而不是连乘：
##   · 连乘会让 N 座 EMP 把敌人叠成近乎静止，且"离开一座"无法精确还原（旧实现的漂移就来自这里）
##   · 取最大值语义也符合玩家直觉 —— 被更强的场覆盖时，弱的那个不再起作用
func refreshSpeed() -> void:
	if baseSpeed <= 0:
		baseSpeed = speed
	var strongest: float = 0.0
	var stale: Array = []
	for src in slowSources:
		# 塔已被卖掉/销毁：清掉，避免字典越攒越大、也避免调用已释放对象
		if not is_instance_valid(src):
			stale.append(src)
			continue
		strongest = maxf(strongest, float(slowSources[src]))
	if not stale.is_empty():
		for key in stale:
			slowSources.erase(key)
	speed = maxi(1, int(round(float(baseSpeed) * (1.0 - strongest))))


## 当前生效的减速比例（0 表示没被减速）。调试/探针用。
func currentSlowRatio() -> float:
	if baseSpeed <= 0:
		return 0.0
	return 1.0 - float(speed) / float(baseSpeed)


# 点击敌人：通知地图选中它
# 这里主动把事件标记为已处理，阻止它继续传导到 map._unhandled_input 的“点空地取消选中”，
# 否则刚弹出的敌人信息面板会被同一击立刻收起来
func onInputEvent(_viewport, _event, _shape_idx):
	if _event.is_action_pressed("click"):
		var vp: Viewport = get_viewport()
		if vp:
			vp.set_input_as_handled()
		Game.enemyClicked.emit(self)

## 物理伤害按 armor 减免，能量伤害忽略 armor，以区分两类攻击的克制关系。
## ── 雷达目标收集（对抗/支援型敌人的"看见防御塔"这一环）──
##
## ⚠️ 这里曾经是整个敌人攻击链路断掉的地方（2026-09-26 修）：
##    各子类（mediumTank / missileTruck / attackHelicopter / medic / suicideTruck）
##    都实现了 _on_radar_area_entered/_exited，但
##    **没有任何敌人场景把 radar.area_entered 信号接上**（对比塔的场景都有接）。
##    结果就是 target 数组恒为空 → pick_target() 永远返回 null → 敌人从不开火。
##    表现："以前会打塔的敌人现在都不打了"。
##
## 现在把处理器收到**基类**，连接写在 scene/enemy/enemy.tscn 上，
## 所有敌人（含以后新加的）自动继承，不会再漏接。
## 子类里的同名函数已删除，避免覆盖基类实现。
##
## 排除 self：敌机主 Area2D 在 layer 2，而各自 radar 的 mask 是 1，
## 正常不会侦测到自己；但万一以后有人改了层，这里兜一手。
func onRadarAreaEntered(area) -> void:
	if area == self or area == null:
		return
	target.append(area)


func onRadarAreaExited(area) -> void:
	if area == self or area == null:
		return
	target.erase(area)


## 取"最近的、仍然有效的"目标；顺手把失效条目清掉。
##
## ⚠️ 三个会开火的敌人（中型坦克 / 导弹车 / 攻击直升机）原来都是直接取 target[0]。
##    那是雷达 area_entered 的**插入顺序**，不是最近的 —— 看着就像"乱打"。
##    而且失效的条目不会被清掉，会一直占着第 0 位，导致后面明明有目标却不开火。
func pickTarget():
	var best = null
	var bestD: float = INF
	var alive: Array = []
	for t in target:
		if not is_instance_valid(t):
			continue
		alive.append(t)
		var d: float = global_position.distance_squared_to(t.global_position)
		if d < bestD:
			bestD = d
			best = t
	target = alive
	return best


func pickTowerTarget() -> Tower:
	var bestTower: Tower = null
	var bestDistanceSquared: float = INF
	for area in target:
		if not is_instance_valid(area) or not area is Tower:
			continue
		var tower: Tower = area as Tower
		var distanceSquared: float = global_position.distance_squared_to(tower.global_position)
		if distanceSquared < bestDistanceSquared:
			bestDistanceSquared = distanceSquared
			bestTower = tower
	return bestTower


func attackTower(tower: Tower) -> void:
	if not is_instance_valid(tower) or not canShot:
		return
	canShot = false
	var bullet = ENEMY_BULLET.instantiate()
	var muzzle: Vector2 = getMuzzlePosition()
	bullet.global_position = muzzle
	bullet.angle = (tower.global_position - muzzle).angle()
	bullet.damage = atk
	bullet.target = tower
	Game.addObj(bullet)
	SoundManage.playAt("mg_fire_b", muzzle, -8.0, randf_range(0.94, 1.08))
	# 开火后坐（没有可见炮塔的敌人会自动跳过）
	playTurretRecoil()
	delayTimer.start()


## 把炮塔转向目标，返回"是否已经瞄准到位"。
## 到位才开火 —— 否则子弹会顺着炮塔当时的朝向飞出去，看着就是乱射。
func aimAt(t, delta: float) -> bool:
	if turret == null or not is_instance_valid(t):
		return false
	# t 是无类型的（Variant），减法结果推不出类型，必须显式标注
	var dir: Vector2 = t.global_position - turret.global_position
	if dir.length_squared() < 0.01:
		return true
	var want: float = dir.angle()
	turret.rotation = lerp_angle(turret.rotation, want, rotationSpeed * delta)
	# wrapf 到 -PI..PI 再比，否则跨 ±180° 时会一直判不到位
	return absf(wrapf(turret.rotation - want, -PI, PI)) < 0.10

func hurt(_num: int, _source = null, _damage_type: String = "physical"):
	# 已经死了就不再结算。
	# ★ 为什么需要这道闸：`queue_free()` 只是**排队**释放，节点要到本帧结束才真的
	#   消失。同一帧里若有多发子弹/炸弹同时命中（霰弹、连锁闪电、爆炸同时扫到多枚），
	#   后续命中会在节点还活着时再次进来 —— 于是 enemyRewarded / enemyDefeated
	#   被重复发出，成就里的击杀数会多算。
	#   dead 标志本来就有（见文件顶部），这里只是真正用起来。
	if dead:
		return
	var actualDamage: float = float(_num)
	if _damage_type == "physical":
		actualDamage *= max(0.0, 1.0 - armor)
	elif _damage_type == "energy":
		actualDamage = float(_num)
	else:
		actualDamage *= max(0.0, 1.0 - armor)

	hp -= int(max(0.0, ceil(actualDamage)))
	# 被击中亮一下（所有敌人通用，材质在基场景上）
	playHitFlash()
	# ---- 血条可见性：全部由敌人这边决定（life_bar.gd 只负责画）----
	#  · 被击中 -> 强制亮 HIT_SHOW_SECONDS 秒（即使此刻正被选中）
	#  · 被选中 -> 一律不显示（攻击范围圈已经说明了他是谁）
	#  · 取消选中 -> 若还在展示窗口内就恢复显示，否则继续藏着
	lifeBar.setValue(hp)
	lifeBar.flashFor(HIT_SHOW_SECONDS)
	if hp <= 0:
		# 先立旗再发奖励：奖励信号与 queue_free() 之外还有别的监听者，
		# 万一其中有人回调 hurt()，dead 已经为 true 就不会二次结算。
		dead = true
		ExplosionManage.playExplosion(global_position)
		# 地面敌人留一坨可以回收的残骸（feature_design.md §十一）。
		# ⚠️ 必须在 freeSelf() **之前**调用 —— 节点一旦 free，读 reward / global_position
		#    都会静默变 null / (0,0)（code_design.md §7.5）。
		# ⚠️ 只在这个"被打死"的分支里生成，**不要**挪到 _exit_tree()：
		#    逃脱、换关卡也会走 _exit_tree()，那会凭空刷出残骸（§11.4 明确写了）。
		spawnWreckage()
		# 击杀金币飘字（独立场景 + 池化，见 feature_design.md §十二）。
		RewardPopup.playAt(global_position, reward)
		Game.enemyRewarded.emit(reward)
		# 特殊敌人额外掉宝石（数量来自 enemyInfo.gemReward，普通敌人是 0 就不发）
		# gemRewardChance < 1 的敌人（如战斗飞机）还要过一道概率，不是每只都掉
		if gemReward > 0 and randf() <= gemRewardChance:
			Game.gemRewarded.emit(gemReward)
		# 成就统计需要知道敌人类型和击杀来源，必须在节点释放之前发出
		Game.enemyDefeated.emit(self, _source)
		freeSelf()
		if _source != null && _source is Tower:
			_source.addExp(rewardExp)

## 敌人退场统一入口：把自己和承载自己的 PathFollow2D 一起释放。
##
## ★ 为什么必须连包裹层一起删：
##   旧场景结构里敌人是 PathFollow2D 里的**嵌套节点**，它的 `owner` 就是这个包裹层，
##   所以当年的 `owner.queue_free()` 会"包裹层 + 敌人"一起删掉。
##   现在敌人自己就是场景根，而包裹层是 base_level.spawnEnemy() 运行时建的
##   （见那里的注释：包裹层放代码里建，是为了避开"嵌套场景覆写"在导出后丢资源的坑）。
##   如果这里只 `queue_free()` 自己，包裹层会永远留在路线下 —— 实测杀光 4 个敌人后
##   路线的子节点数一个都没少，整关每刷一个敌人就漏一个节点。
##
##   所以这里补回旧行为：先删承载自己的包裹层（连自己一起走），
##   没有包裹层时（例如单独放进场景测试）就退化成只删自己。
func freeSelf() -> void:
	var wrapper: Node = get_parent()
	if wrapper != null and wrapper is PathFollow2D:
		# 先删包裹层：它连同子节点（自己）一起被释放，
		# 不会出现"自己已释放、包裹层成孤儿"的中间态。
		wrapper.queue_free()
		return
	queue_free()





func playHitFlash() -> void:
	setHitFlash(1.0)
	if hitFlashTween != null and hitFlashTween.is_valid():
		hitFlashTween.kill()
	hitFlashTween = create_tween()
	hitFlashTween.tween_method(setHitFlash, 1.0, 0.0, HIT_FLASH_TIME)


func setHitFlash(v: float) -> void:
	# base / turret 都可能不存在（无人机之类只有 base），逐个判空
	for n in [base, turret]:
		if n == null:
			continue
		var m: ShaderMaterial = n.material as ShaderMaterial
		if m != null:
			m.set_shader_parameter("flash", v)




func playTurretRecoil() -> void:
	# 没有可见炮塔（飞行单位 / 卡车）直接跳过
	if turret == null or not is_instance_valid(turret) or not turret.visible:
		return
	# 基准 offset 是场景里配的（如装甲坦克 Vector2(17, 0)），第一次开火时记下来：
	# 子类的 _ready() 基本都不调 super()，不能指望在这里统一初始化。
	if not turretOffsetCached:
		turretOffsetBase = turret.offset
		turretOffsetCached = true
	# 连射时上一段后坐还没播完就重来，避免几段补间叠在一起
	if recoilTween != null and recoilTween.is_valid():
		recoilTween.kill()
	turret.offset = turretOffsetBase
	recoilTween = create_tween()
	recoilTween.tween_property(turret, "offset",
		turretOffsetBase + Vector2(-turretRecoil, 0.0), RECOIL_BACK_TIME)
	recoilTween.tween_property(turret, "offset", turretOffsetBase, RECOIL_RETURN_TIME)

## 死亡时留一坨可回收的残骸（feature_design.md §十一）。
##
## 规则（§11.2）：**地面单位都掉，空中单位不掉**。
## 理由：空中单位被击落可以理解为"掉在场外"；这条规则也顺带避开了
## "飞机掉在航线正下方、机甲够得着但路线挡着"的尴尬。
##
## 存活时长按身价分档（越贵留得越久，给机甲更多赶过去的时间）。
func spawnWreckage() -> void:
	if flying:
		return
	# 身体贴图：取敌人当前那一帧。贴图是运行期才知道的（每种敌人不一样），
	# 所以残骸场景里没法预摆，只能在这里传进去。
	var tex: Texture2D = null
	if base != null:
		tex = base.sprite_frames.get_frame_texture(base.animation, base.frame) if base.sprite_frames != null else null
	ExplosionManage.spawnWreckage(global_position, tex, reward, wreckageLifetimeFor(reward))


## 残骸存活时长（秒）按身价分档，见 §11.2 的表。
## 抽成静态函数，方便探针直接核对每一档，不用去生成一个敌人。
static func wreckageLifetimeFor(reward: int) -> float:
	if reward >= 40:
		return 16.0    # 实验坦克
	if reward >= 15:
		return 12.0    # 重型 / 装甲坦克
	if reward >= 6:
		return 10.0    # 小型
	return 8.0         # 迷你坦克 / 突击车 / 自爆车


## 恢复生命值并限制在最大值内，同时弹出"绿色 + 号"回复特效。
##
## 特效挂在 addHp 上、而不是写在 medic.gd 里：addHp 是**所有**回血的唯一入口，
## 以后再有别的治疗来源（道具 / 技能）也自动带特效，不会漏。
## 生命周期交给 ExplosionManage 那一套（播完自毁），这里不用自己管。
##
## ── 特效参数（写在 scene/fx/heal_particles.tscn 里，这里记一份原因）──
## 6 个 + 号就够读成"几个"。贴图 144px，缩到 0.20~0.32 约 29~46px，比敌人本体小一圈。
## 试过 9 个 × 0.42~0.62，在窄锥角里全叠成一团绿疙瘩 —— 所以：
##   · amount 6
##   · explosiveness 0.08（让 + 号在 lifetime 里**陆续**冒出，而不是同一帧全炸出来）
##   · spread 90° + 初速 170~280（先向四周散开再一起上飘，竖向才拉得开间距）
##   · angle ±30°（随机旋转，避免 6 个一模一样的十字排一起像复制粘贴）
func addHp(_num: int):
	if _num <= 0:
		return
	# 已经满血就别弹特效 —— 维修车锁到满血目标时不该刷一串 + 号
	var wasFull: bool = hp >= maxHp
	hp += _num
	if hp > maxHp:
		hp = maxHp
	lifeBar.setValue(hp)
	if not wasFull:
		var fx: Node = (load(HEAL_FX) as PackedScene).instantiate()
		fx.position = global_position + Vector2(0, -26)
		ExplosionManage.add_child(fx)

func fire(_t):
	pass


# 开火冷却结束：复位 canShot，允许下一次开火
# 对抗型敌人（中型坦克 / 导弹车 / 攻击直升机 / 维修车）开火后会把 canShot 置 false
# 并启动 delay 定时器，靠这个回调复位，否则整局只会开火一次
func onDelayTimeout() -> void:
	canShot = true


## 选中 / 取消选中。选中期间自己画攻击范围圈（见 _draw）。
##
## 由 map.gd 在敌人信息面板开合时调用 —— 面板才是"谁被选中"的唯一状态，
## 敌人这边只跟着它走，不自己判断点击。
func setSelected(on: bool) -> void:
	if selected == on:
		return
	selected = on
	# 取消选中时把扫描线归零，下次选中的观感每次都一样
	if not selected:
		radarSweepAngle = 0.0
	# 选中期间**不显示血条**：攻击范围圈已经在说"我选中了谁"，再叠一条血条只会让画面更乱。
	# 取消选中时，如果还处在"被击中"的展示窗口里就恢复显示，否则继续藏着 ——
	# 展示窗口本身由 lifeBar 的计时器记着，这里不用再存一份状态。
	if lifeBar:
		if selected:
			lifeBar.conceal()
		elif lifeBar.isShowing():
			lifeBar.flashFor(lifeBar.remaining())
	queue_redraw()


func _physics_process(_delta):
	# 选中时：扫描线转起来 + 每物理帧重绘（和 tower.gd 的写法一致）
	if selected:
		radarSweepAngle = fmod(radarSweepAngle + _delta * RADAR_SCAN_SPEED, TAU)
		queue_redraw()
	if points.size() == 0:
		return
	parent.progress += speed * _delta
	if parent.progress_ratio >= 1:
		Game.enemyEscaped.emit(lossPoints)
		freeSelf()


## 选中时画攻击范围 —— **与防御塔完全同一套画法**（tower.gd::_draw）：
## 同一个颜色、同样的填充/外圈/3 道同心环/旋转扫描扇 + 扫描线。
##
## 玩家反馈"应该和防御塔点击显示攻击范围一样"，所以这里刻意不另设计一套样式；
## 参数与 tower.gd 逐条对齐（0.12 填充 / 0.8 外圈 / 内环 0.15 /
## 24 段扇尾 60° / 扫描线 1.0 宽 2.0）。要改观感就两边一起改。
##
## 只在 showsRange 为真时画：维修车（治疗）与自爆车（撞击）虽然 atk > 0，
## 但它们的"范围"不是打塔射程，画出来会误导（见 feature_design.md §9.3）。
func _draw() -> void:
	if not selected or not showsRange or radarScope <= 0.0:
		return
	var radarColor: Color = Color(0.25, 0.75, 1.0, 1.0)
	draw_circle(Vector2.ZERO, radarScope,
		Color(radarColor.r, radarColor.g, radarColor.b, 0.12))
	draw_arc(Vector2.ZERO, radarScope, 0.0, TAU, 64,
		Color(radarColor.r, radarColor.g, radarColor.b, 0.8), 2.0)
	for i in range(1, 4):
		var r = radarScope * (i / 4.0)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64,
			Color(radarColor.r, radarColor.g, radarColor.b, 0.15), 1.0)
	var segments: int = 24
	var tailSpan: float = PI / 3.0
	for s in range(segments):
		var t = float(s) / segments
		var a = radarSweepAngle - tailSpan * t
		var alpha = (1.0 - t) * 0.5
		var nextA = radarSweepAngle - tailSpan * (float(s + 1) / segments)
		var p1 = Vector2(cos(a), sin(a)) * radarScope
		var p2 = Vector2(cos(nextA), sin(nextA)) * radarScope
		draw_polygon(
			PackedVector2Array([Vector2.ZERO, p1, p2]),
			PackedColorArray([
				Color(radarColor.r, radarColor.g, radarColor.b, alpha),
				Color(radarColor.r, radarColor.g, radarColor.b, alpha),
				Color(radarColor.r, radarColor.g, radarColor.b, 0.0)
			])
		)
	draw_line(
		Vector2.ZERO,
		Vector2(cos(radarSweepAngle), sin(radarSweepAngle)) * radarScope,
		Color(radarColor.r, radarColor.g, radarColor.b, 1.0),
		2.0
	)
	if lifeBar == null or not is_instance_valid(lifeBar):
		return
	# ⚠️ parent 可能为 null：`parent` 是各子类 `_ready()` 里
	#    `get_parent() as PathFollow2D` 拿到的。只要敌人不是挂在 PathFollow2D 下
	#    （编辑器里预览、单独实例化、测试场景里直接 add_child 到地图），它就会是 null。
	#
	#    这一行原本是无保护的 `lifeBar.global_position = parent.global_position + ...`，
	#    一旦 parent 为 null，**整个 _draw() 在最后一行抛异常**。射程圈是在这行之前画的，
	#    所以表现就是"圈画出来了但不会更新"—— 重绘每次都中断在半路。
	if parent == null or not is_instance_valid(parent):
		# 没挂在路径上：直接用自己的位置，射程圈和血条都还能正常显示
		lifeBar.global_position = global_position + LIFE_BAR_OFFSET
		return
	lifeBar.global_position = parent.global_position + LIFE_BAR_OFFSET
