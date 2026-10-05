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
var maxHp: int = 100 # 最大血量（初始化时由 hp 同步）

var vec = Vector2.ZERO
var target = [] # 目标
var points = [] # 路径点
var pointIndex = 0
var dead = false # 是否死亡
var rotationSpeed = 10
var canShot = true

var parent: PathFollow2D

const ENEMY_BULLET: PackedScene = preload("res://scene/bullet/enemy_bullet.tscn")

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
@onready var lifeBar = $LifeBar
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

var _recoilTween: Tween
var _turretOffsetBase: Vector2 = Vector2.ZERO
var _turretOffsetCached: bool = false
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
	reward = int(info.get("reward", reward))
	lossPoints = int(info.get("lossPoints", lossPoints))
	rewardExp = int(info.get("rewardExp", rewardExp))
	gemReward = int(info.get("gemReward", gemReward))
	gemRewardChance = float(info.get("gemRewardChance", gemRewardChance))
	armor = float(info.get("armor", armor))
	flying = bool(info.get("flying", flying))
	atk = int(info.get("atk", atk))
	# 无尽模式难度缩放：hp / atk 乘一个随波次上涨的系数（普通关卡恒为 1.0）
	if Game.enemyScale != 1.0:
		hp = int(ceil(float(hp) * Game.enemyScale))
		maxHp = hp
	if Game.enemyAtkScale != 1.0:
		atk = int(ceil(float(atk) * Game.enemyAtkScale))
	shootDelay = float(info.get("shootDelay", shootDelay))
	radarScope = float(info.get("scope", radarScope))
	if shootDelay > 0:
		delayTimer.wait_time = shootDelay
	if lifeBar:
		lifeBar.maxHp = hp
		lifeBar.value = hp
	# 炮口标记的位置也在这里写（理由见 muzzleOffset 的注释：场景里改会被编辑器丢掉）
	if muzzleMarker != null:
		muzzleMarker.position = Vector2(muzzleOffset, 0.0)
	_applyRadarScope()


# 按 radarScope 同步雷达碰撞体半径（数值唯一来源是 Game.enemyInfo 的 scope 字段）
# 推进型(radarScope <= 0)不参战，直接关闭雷达侦测，避免空转物理检测
# 场景里没有配置 radar/shape 形状的敌人（自爆车、侦察无人机）在这里按需补一个圆形碰撞体
func _applyRadarScope() -> void:
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


# 点击敌人：通知地图选中它
# 这里主动把事件标记为已处理，阻止它继续传导到 map._unhandled_input 的“点空地取消选中”，
# 否则刚弹出的敌人信息面板会被同一击立刻收起来
func _onInputEvent(_viewport, _event, _shape_idx):
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
func _onRadarAreaEntered(area) -> void:
	if area == self or area == null:
		return
	target.append(area)


func _onRadarAreaExited(area) -> void:
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
	if lifeBar:
		lifeBar.visible = true
		lifeBar.value = hp
	if hp <= 0:
		ExplosionManage.playExplosion(global_position)
		Game.enemyRewarded.emit(reward)
		# 特殊敌人额外掉宝石（数量来自 enemyInfo.gemReward，普通敌人是 0 就不发）
		# gemRewardChance < 1 的敌人（如战斗飞机）还要过一道概率，不是每只都掉
		if gemReward > 0 and randf() <= gemRewardChance:
			Game.gemRewarded.emit(gemReward)
		# 成就统计需要知道敌人类型和击杀来源，必须在节点释放之前发出
		Game.enemyDefeated.emit(self, _source)
		owner.queue_free()
		if _source != null && _source is Tower:
			_source.addExp(rewardExp)

## ── 被击中的"变亮"反馈 ──
## 材质挂在 scene/enemy/enemy.tscn 的 base / turret 上，所有敌人共用（派生场景继承得到）。
## 这里只负责把 shader 的 flash 参数从 1 补间到 0。
const HIT_FLASH_TIME := 0.10

var _hitFlashTween: Tween


func playHitFlash() -> void:
	_setHitFlash(1.0)
	if _hitFlashTween != null and _hitFlashTween.is_valid():
		_hitFlashTween.kill()
	_hitFlashTween = create_tween()
	_hitFlashTween.tween_method(_setHitFlash, 1.0, 0.0, HIT_FLASH_TIME)


func _setHitFlash(v: float) -> void:
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
	if not _turretOffsetCached:
		_turretOffsetBase = turret.offset
		_turretOffsetCached = true
	# 连射时上一段后坐还没播完就重来，避免几段补间叠在一起
	if _recoilTween != null and _recoilTween.is_valid():
		_recoilTween.kill()
	turret.offset = _turretOffsetBase
	_recoilTween = create_tween()
	_recoilTween.tween_property(turret, "offset",
		_turretOffsetBase + Vector2(-turretRecoil, 0.0), RECOIL_BACK_TIME)
	_recoilTween.tween_property(turret, "offset", _turretOffsetBase, RECOIL_RETURN_TIME)

## 恢复生命值并限制在最大值内；待补充回复特效。
func addHp(_num: int):
	hp += _num
	if hp > maxHp:
		hp = maxHp
	lifeBar.value = hp

func fire(_t):
	pass


# 开火冷却结束：复位 canShot，允许下一次开火
# 对抗型敌人（中型坦克 / 导弹车 / 攻击直升机 / 维修车）开火后会把 canShot 置 false
# 并启动 delay 定时器，靠这个回调复位，否则整局只会开火一次
func _onDelayTimeout() -> void:
	canShot = true


func _physics_process(_delta):
	if points.size() == 0:
		return
	parent.progress += speed * _delta
	if parent.progress_ratio >= 1:
		Game.enemyEscaped.emit(lossPoints)
		owner.queue_free()
