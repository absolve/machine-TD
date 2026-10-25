extends Area2D
class_name Tower

@export var hp = 0 # 防御塔血量
@export var maxHp = 0 # 最大血量
@export var radarScope = 500 # 雷达范围
@export var type: Game.towerType = Game.towerType.machineGunTower

var delay = 0.1 # 开火延迟
var target = [] # 目标集合
var canShot = true
var selected = false # 选中
var rotationSpeed = 10
var money = 0 # 花费
var sellingPrice = 0 # 售价
var coverGrid: Array[Vector2i] = [] # 占用的格子
var targetValue: int = 1 # 目标价值 敌人攻击的优先级
var atk: int = 0 # 攻击力
var level: int = 1 # 等级
var towerExp: int = 0 # 经验值
var initTime = 1 # 初始化时间 秒

## 无敌状态（由能力技能施加）：无敌期间免疫一切伤害
var invincible: bool = false
var invincibleLeft: float = 0.0

## 修满血的最高费用占造价的百分比（残血越多越贵，满血时为 0）
const REPAIR_COST_RATIO := 0.5
const LOW_HEALTH_RATIO: float = 0.5

## 修理费用：按“缺失血量比例 × 造价 × REPAIR_COST_RATIO”计算，向上取整。
## 满血返回 0（无需修理）。
var repairCost: int:
	get:
		if maxHp <= 0 or hp >= maxHp:
			return 0
		var missingRatio: float = float(maxHp - hp) / float(maxHp)
		return maxi(1, int(ceil(float(money) * REPAIR_COST_RATIO * missingRatio)))

var radarSweepAngle: float = 0.0
const RADAR_SCAN_SPEED := 1.8
## 开火动画的播放倍速（喂给 player.speed_scale）。
##
## 机枪 / 加农 / 火箭的 `player` 里有一个 "fire" 动画（后坐：把 turret.offset 推回去再弹回）。
## **动画长度是按 1 级射速配的**，而升级会缩短 `delay`（reload）：
##   机枪 0.2 → 0.18 → 0.16   加农 0.8 → 0.72 → 0.65   火箭 1.5 → 1.35 → 1.2
## 射速快了动画却还是原来的长度，就会"枪口都回位了子弹才出去"或者几个后坐叠在一起。
## 所以倍速要**按 reload 缩放的倍数走**：`aniSpeed = 1 级的 reload / 当前 reload`。
## 1 级时正好是 1.0（动画原速），升级后同步变快。
var aniSpeed = 1
## 1 级的 reload —— 算 aniSpeed 的基准；不参与升级的塔保持 0 表示"不用管"
var baseDelay = 0

## ── 主动技能（设计见 feature_design.md §十八）──
##
## ⚠️ 本模块与**升级系统**的边界（用户明确要求两者不能冲突）：
##   `atk` / `delay` / `radarScope` 是**升级系统拥有的基值**，`levelUp()` 会整体覆盖它们。
##   技能**只提供派生值**（effectiveAtk / effectiveDelay / effectiveScope），
##   任何时候都不写回基值 —— 所以"升级把技能效果清掉"或"技能×升级双倍叠加"都不可能发生。
##   同理，`delayTimer.wait_time` 与 `raderShape.shape.radius` 这两处派生写入也统一收口到
##   `applyFireRate()` / `applySight()`，升级与技能都走这里。
var skillKind: String = ""            # "" / "toggle" / "timed" / "instant"
var skillDef: Dictionary = {}         # Game.towerSkills 里的那一条
var skillActiveLeft: float = 0.0      # timed：剩余生效秒数
var skillCooldownLeft: float = 0.0    # 冷却 / 切换 CD 剩余
var skillOn: bool = false             # toggle：当前是否处于"第二种模式"
var skillDisabledLeft: float = 0.0    # 停摆剩余（机甲用；>0 时整机失效）
## timed 技能的自损累加器：按每秒折算，攒够 1 点才真的扣一次血
var skillSelfDamageAcc: float = 0.0

## 炮口到轴心的像素距离 —— 代码里写 `marker.position`，**不要**去场景里改 Marker2D。
##
## ⚠️ 为什么放代码里：Marker2D 在基场景 Tower.tscn 里是 (0,0)，子场景就算覆盖了，
##    只要在编辑器里一保存那个子场景，覆盖就**会被丢掉**（特斯拉那次就丢了，
##    表现是"闪电从塔中心发出来"）。写成导出变量，值跟着脚本走，谁也覆盖不掉。
##
## 取值 = 该塔炮塔贴图的炮口到贴图中心的距离，再补上 `turret.offset.x`
## （算法：贴图内最右绘制像素 x − 贴图宽/2 + turret.offset.x）：
##   机枪 31 / 加农 50 / 火箭 46 / EMP 0 / 激光 0 / 特斯拉 0 / 无人机 0
## 注意炮塔贴图的 `AnimatedSprite2D.offset` 只是**视觉**平移，不影响子节点，
## 所以这里必须显式写，不能指望它把 Marker2D 一起带走。
##
## ⚠️ 单位是 **turret 节点的本地坐标**，要乘 `turret.scale` 才是世界距离。
##    炮口闪光 `spark` 挂在塔根节点下（不受 turret.scale 影响），所以它的
##    `offset.x` 要写成 `muzzleOffset × turret.scale` 才会正好落在炮口上
##    （火箭塔 scale=0.6：46 × 0.6 = 28）。
@export var muzzleOffset: float = 0.0


@onready var rader = $radar
@onready var raderShape = $radar/CollisionShape2D
@onready var base = $base
@onready var turret = $turret
@onready var delayTimer = $Delay
@onready var marker = $turret/Marker2D
@onready var player = $Player
@onready var initBar = $ProgressBar
@onready var towerRank = $TowerRank
@onready var lifeBar = $LifeBar
@onready var deploySound = $DeploySound
@onready var spark = $Spark
@onready var damageFx: Node2D = $DamageFx
@onready var flameParticles: CPUParticles2D = $DamageFx/Flames
@onready var smokeParticles: CPUParticles2D = $DamageFx/Smoke
# 开火特效播放器：只有配置了炮口闪光的塔才有这个节点，其余塔为 null
@onready var sparkPlayer = get_node_or_null("SparkPlayer")


func _ready() -> void:
	# 所有防御塔统一进 "tower" 组：机甲的激光靠它找维修目标（mech.gd::pickRepairTarget）。
	# 用组而不是遍历地图子节点 —— 塔是 map 的直接子节点，但组查询不受层级影响，
	# 以后塔要是挪到别的容器下也不会悄悄失效。
	add_to_group("tower")
	setupSkill()
	if raderShape.shape:
		raderShape.shape.radius = effectiveScope()
	if maxHp <= 0 and hp > 0:
		maxHp = hp
	if hp <= 0 and maxHp > 0:
		hp = maxHp
	# 炮口位置由代码写（原因见 muzzleOffset 的注释：场景里的覆盖会被编辑器丢掉）
	if marker != null:
		marker.position = Vector2(muzzleOffset, 0.0)
	# 记下 1 级的 reload 当基准，算出当前的动画倍速。
	# ⚠️ 必须**建塔时**就抓一次 —— 升级会把 delay 改掉，之后再取就再也拿不到 1 级的值了。
	#    towerInfo 里存的就是 1 级数值，所以直接查表，不依赖"此刻的 delay 恰好是 1 级"。
	baseDelay = delay
	# 统一入口：既写 delayTimer.wait_time，也重算开火动画倍速
	# （baseDelay 必须先就位，否则 refreshAniSpeed 会算出 0 倍速）
	applyFireRate()
	monitorable = false
	set_physics_process(false)
	#set_process(false) # 只有进入无敌状态才需要逐帧倒计时
	deploySound.play()
	var tween = create_tween()
	tween.tween_property(initBar, "value", 100, initTime)
	tween.tween_callback(init)
	call_deferred("updateStatusUi")

func getTarget():
	var temp = null
	if target.size() == 1:
		temp = target[0]
	elif target.size() > 1:
		temp = target[0]
	
	return temp

func canTarget(area: Area2D) -> bool:
	if not is_instance_valid(area) or not area is Enemy:
		return false
	var canTargetAir: bool = type in [Game.towerType.droneBase, Game.towerType.laserTower, Game.towerType.rocketTower]
	return not area.flying or canTargetAir

func addTarget(area: Area2D) -> void:
	if not canTarget(area):
		return
	if not target.has(area):
		target.push_back(area)

func init():
	initBar.visible = false
	base.modulate.a = 1
	turret.modulate.a = 1
	monitorable = true
	input_pickable = true
	set_physics_process(true)
	

func hideSelect():
	selected = !selected
	queue_redraw()
	#update_status_ui()
	Game.towerClicked.emit(self, selected)

# 增加经验
func addExp(amount: int) -> void:
	if level >= TowerUpgradeManager.MAX_LEVEL:
		#update_status_ui()
		return
	# 没有升级配置、或被明确排除的塔（如 EMP 干扰塔）不参与升级
	if not TowerUpgradeManager.canUpgrade(type):
		#update_status_ui()
		return
	towerExp += amount
	var threshold = TowerUpgradeManager.getExpThreshold(type, level)
	if towerExp >= threshold:
		levelUp()
		towerExp -= threshold
	#update_status_ui()

func updateStatusUi() -> void:
	if maxHp <= 0:
		maxHp = max(hp, 1)
	var isLowHealth: bool = float(hp) / float(maxHp) < LOW_HEALTH_RATIO
	damageFx.visible = isLowHealth
	flameParticles.emitting = isLowHealth
	smokeParticles.emitting = isLowHealth
	if lifeBar:
		lifeBar.setMax(maxHp)
		lifeBar.setValue(hp)
		lifeBar.flashFor(lifeBar.showSeconds)
	# 修理按钮依赖血量状态刷新（右侧信息面板每帧调用 refresh）
	
func levelUp() -> void:
	level += 1
	var levelConfig: Dictionary = TowerUpgradeManager.getLevelConfig(type, level)
	if levelConfig.has("atk"):
		atk = levelConfig.atk
	if levelConfig.has("reload"):
		delay = levelConfig.reload
		# ⚠️ 这里**只改基值 delay**，实际生效值交给 applyFireRate() 派生。
		#   如果在这里直接写 delayTimer.wait_time = delay，正在生效的限时技能
		#   （比如机枪塔过热）就会被这一次升级静默清掉 —— 那正是"技能与升级冲突"。
	if levelConfig.has("scope"):
		radarScope = levelConfig.scope
		# 同理：只改基值，碰撞体半径由 applySight() 按"基值 × 技能倍率"派生
	applyFireRate()
	applySight()
	towerRank.setLevel(level)
	playUpgradeGlow()
	updateStatusUi()
	TowerUpgradeManager.towerLeveledUp.emit(self, level)
	

## ── 主动技能 ──
##
## 对外只暴露这几件事，具体数值全部来自 `Game.towerSkills`：
##   hasSkill() / canUseSkill() / useSkill() / isSkillActive() / isDisabled()
##   面板按钮每帧读它们决定文案与可点状态。
func setupSkill() -> void:
	var def = Game.towerSkills.get(type, {})
	skillDef = def if def is Dictionary else {}
	skillKind = str(skillDef.get("kind", ""))
	skillOn = false
	skillActiveLeft = 0.0
	skillCooldownLeft = 0.0
	skillDisabledLeft = 0.0
	skillSelfDamageAcc = 0.0


func hasSkill() -> bool:
	return not skillDef.is_empty() and not skillKind.is_empty()


## 限时技能是否正在生效
func isSkillActive() -> bool:
	return skillKind == "timed" and skillActiveLeft > 0.0


## 停摆中（机甲专用）：>0 时整个单位失效
func isDisabled() -> bool:
	return skillDisabledLeft > 0.0


## 能不能用（冷却 / 停摆 / 已在生效 / 血量门槛）。
## ⚠️ 这里只管"按钮"；子类真正干活前还要各自再问一次 `isDisabled()`。
func canUseSkill() -> bool:
	if not hasSkill():
		return false
	if isDisabled() or skillCooldownLeft > 0.0:
		return false
	if skillKind == "timed" and isSkillActive():
		return false
	var minRatio: float = float(skillDef.get("minHpRatio", 0.0))
	if minRatio > 0.0 and maxHp > 0 and float(hp) / float(maxHp) < minRatio:
		return false
	return true


## 统一入口：按 kind 分发。返回是否真的生效（失败时 UI 应当给反馈）。
func useSkill() -> bool:
	if not canUseSkill():
		return false
	match skillKind:
		"toggle":
			return toggleSkill()
		"timed":
			return startTimedSkill()
		"instant":
			return runInstantSkill()
	return false


## 功能切换：翻转模式 + 开始切换 CD（只防连点，不影响强度）
func toggleSkill() -> bool:
	skillOn = not skillOn
	skillCooldownLeft = float(skillDef.get("switchCooldown", 3.0))
	applyFireRate()
	applySight()
	onSkillModeChanged()
	return true


func startTimedSkill() -> bool:
	skillActiveLeft = float(skillDef.get("duration", 0.0))
	if skillActiveLeft <= 0.0:
		return false
	skillSelfDamageAcc = 0.0
	applyFireRate()
	applySight()
	onSkillModeChanged()
	return true


func endTimedSkill() -> void:
	skillActiveLeft = 0.0
	skillCooldownLeft = float(skillDef.get("cooldown", 0.0))
	# 有些技能结束后还要额外停一段（EMP 的"停转 3 秒"）
	var after: float = float(skillDef.get("disableAfter", 0.0))
	if after > 0.0:
		skillDisabledLeft = after
	applyFireRate()
	applySight()
	onSkillModeChanged()


## 瞬发技能的默认实现：没有特殊效果的塔就当"无事发生"。
## 机甲覆写它做群体治疗。
func runInstantSkill() -> bool:
	onSkillModeChanged()
	return true


## 模式/生效状态变化后的钩子（子类用来刷新自绘、渐变等）。默认什么也不做。
func onSkillModeChanged() -> void:
	queue_redraw()


## 每物理帧推进技能计时。由 `_physics_process` 统一调用。
func tickSkill(delta: float) -> void:
	if not hasSkill():
		return
	if skillCooldownLeft > 0.0:
		skillCooldownLeft = maxf(0.0, skillCooldownLeft - delta)
	if skillDisabledLeft > 0.0:
		skillDisabledLeft = maxf(0.0, skillDisabledLeft - delta)
	if isSkillActive():
		# 自损按"每秒多少点"折算，攒够 1 点再扣，避免每帧扣 0 点永远扣不动
		var selfDps: float = float(skillDef.get("selfHpPerSec", 0.0))
		if selfDps > 0.0:
			skillSelfDamageAcc += selfDps * delta
			if skillSelfDamageAcc >= 1.0:
				var dmg: int = int(floor(skillSelfDamageAcc))
				skillSelfDamageAcc -= float(dmg)
				applySelfDamage(dmg)
		skillActiveLeft -= delta
		if skillActiveLeft <= 0.0:
			endTimedSkill()


## 技能自损。**故意绕过 `hurt()` 的无敌判定** —— 否则「无敌 + 过热」就是白送的组合。
## 但死亡流程必须和被打爆完全一致，所以共用 `die()`。
func applySelfDamage(amount: int) -> void:
	if amount <= 0 or hp <= 0:
		return
	hp -= amount
	if lifeBar:
		lifeBar.setMax(maxHp)
		lifeBar.setValue(hp)
		lifeBar.flashFor(lifeBar.showSeconds)
	updateStatusUi()
	if hp <= 0:
		die()


## ── 派生值：技能只在这里叠加，不碰基值 ──

func skillAtkMul() -> float:
	if skillKind == "toggle" and skillOn:
		return float(skillDef.get("atkMul", 1.0))
	if isSkillActive():
		return float(skillDef.get("atkMul", 1.0))
	return 1.0


func skillDelayMul() -> float:
	if skillKind == "toggle" and skillOn:
		return float(skillDef.get("delayMul", 1.0))
	if isSkillActive():
		return float(skillDef.get("delayMul", 1.0))
	return 1.0


func skillSightMul() -> float:
	if skillKind == "toggle" and skillOn:
		return float(skillDef.get("sightMul", 1.0))
	if isSkillActive():
		return float(skillDef.get("sightMul", 1.0))
	return 1.0


## 技能期间的攻击力。**所有子类的 fire() 都必须用它**，不要直接读 atk。
func effectiveAtk() -> int:
	var mul: float = skillAtkMul()
	if is_equal_approx(mul, 1.0):
		return atk
	return maxi(1, int(round(float(atk) * mul)))


func effectiveDelay() -> float:
	return maxf(0.02, delay * skillDelayMul())


func effectiveScope() -> float:
	return radarScope * skillSightMul()


## 受到伤害的倍率（铁箱塔的应急装甲用）。在 `hurt()` 里相乘。
func damageTakenMul() -> float:
	if isSkillActive():
		return float(skillDef.get("damageTakenMul", 1.0))
	return 1.0


## 技能期间是否"整个失效"（机甲）。子类在行为入口调用。
func canAct() -> bool:
	return not isDisabled()


## **唯一**写 `delayTimer.wait_time` 的地方（升级与技能都走这里）
func applyFireRate() -> void:
	if delayTimer != null:
		delayTimer.wait_time = effectiveDelay()
	refreshAniSpeed()


## **唯一**写雷达碰撞体半径的地方。画圈用的是 effectiveScope()，两边必须同源。
func applySight() -> void:
	var scopeNow: float = effectiveScope()
	if raderShape != null and raderShape.shape:
		raderShape.shape.radius = scopeNow
	queue_redraw()


# 升级闪光: 启用 shader -> 亮度淡入 -> 闪烁 -> 淡出 -> 关闭
func playUpgradeGlow() -> void:
	# ⚠️ 必须判空：不是每种塔都同时有 base 和 turret 两个精灵
	#   （droneBase 就没有 turret），而且材质万一不是 ShaderMaterial
	#   时 as 的结果是 null，直接 set_shader_parameter 会报错。
	#   stopGlow() 里本来就有判空，这里之前漏了。
	var bm: ShaderMaterial = base.material as ShaderMaterial
	var tm: ShaderMaterial = turret.material as ShaderMaterial
	if bm:
		bm.set_shader_parameter("enable_flash", true)
	if tm:
		tm.set_shader_parameter("enable_flash", true)

	var tw: Tween = create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(stopGlow)
	# tw.tween_method(setGlowIntensity, 1.0, 0.0, 0.3) # 0.3s 淡出
	# tw.tween_callback(stopGlow)


# func setGlowIntensity(value: float) -> void:
# 	(base.material as ShaderMaterial).set_shader_parameter("brightness", value)
# 	(turret.material as ShaderMaterial).set_shader_parameter("brightness", value)


func stopGlow() -> void:
	var bm: ShaderMaterial = base.material as ShaderMaterial
	var tm: ShaderMaterial = turret.material as ShaderMaterial
	if bm:
		bm.set_shader_parameter("enable_flash", false)
	if tm:
		tm.set_shader_parameter("enable_flash", false)


func onDelayTimeout():
	canShot = true


## 1 级的 reload。查 game.gd 的 towerInfo（那里存的就是 1 级数值）。
## 查不到就退回"当前 delay"—— 退回的值会让 aniSpeed 恰好是 1.0，
## 也就是"不动画"，比乱算一个倍速安全。
func lookupBaseDelay() -> float:
	var info = Game.towerInfo.get(type)
	if info is Dictionary and info.has("reload"):
		var r: float = float(info["reload"])
		if r > 0.0:
			return r
	return maxf(delay, 0.001)


## 按当前 reload 重算开火动画倍速，并写进 player。
##
## 公式：`aniSpeed = 1 级 reload / 当前 reload`
##   机枪 1级 0.20 → lv2 0.222 / lv3 0.25
##   加农 1级 0.80 → lv2 1.111 / lv3 1.231
##   火箭 1级 1.50 → lv2 1.111 / lv3 1.25
## 1 级时是 1.0（动画原速），升级后同步变快 —— 后坐和射速永远对得上。
func refreshAniSpeed() -> void:
	var effective: float = effectiveDelay()
	if effective <= 0.0:
		return
	# 用**派生后**的开火间隔：技能改射速时后坐动画也要跟着变快/变慢，
	# 否则会出现"枪口都回位了子弹才出去"或者几个后坐叠在一起。
	aniSpeed = baseDelay / effective
	if player == null:
		return
	# 只有**真的有 "fire" 动画**的塔才写 speed_scale。
	# ⚠️ 这道闸不是死代码：EMP / 特斯拉 / 激光 / 无人机基地的 player 里没有 fire 动画，
	#    少了它就会把一个用不上的倍速写进去，看着像"接了动画其实没有"。
	#    两道查法（默认库 / 显式取 "" 库）实测结果一致，双保险而已。
	#var lib: AnimationLibrary = player.get_animation_library("")
	#var has_fire: bool = player.has_animation("fire") or (lib != null and lib.has_animation("fire"))
	#if not has_fire:
		#return
	#if not is_equal_approx(player.speed_scale, aniSpeed):
	player.speed_scale = aniSpeed


# 无敌倒计时：只在无敌期间运行
# func _process(delta: float) -> void:
# 	if not invincible:
# 		set_process(false)
# 		return
# 	_invincible_left -= delta
# 	if _invincible_left <= 0.0:
# 		_set_invincible_visual(false)


# 施加无敌（由能力技能系统调用）
func setInvincible(duration: float) -> void:
	if duration <= 0.0:
		return
	invincible = true
	# 重复施加时取更长的剩余时间，不做叠加
	invincibleLeft = maxf(invincibleLeft, duration)
	setInvincibleVisual(true)
	set_process(true)


# 无敌期间用安全黄色高亮，和"我方强化"的视觉约定一致
func setInvincibleVisual(on: bool) -> void:
	if on:
		modulate = Color(1.0, 0.92, 0.55, 1.0)
		return
	invincible = false
	invincibleLeft = 0.0
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	set_process(false)

func hurt(_num: int, _source = null, _damage_type: String = "physical"):
	if invincible:
		return
	if hp <= 0:
		return
	var actualDamage: float = float(_num)
	if _damage_type == "physical":
		actualDamage *= 1.0
	elif _damage_type == "energy":
		actualDamage = float(_num)
	else:
		actualDamage *= 1.0
	# 技能减伤（铁箱塔的应急装甲）。放在最后统一乘，物理/能量两条通道都覆盖。
	actualDamage *= damageTakenMul()

	hp -= int(max(0.0, ceil(actualDamage)))
	if maxHp <= 0:
		maxHp = max(hp, 1)
	if lifeBar:
		lifeBar.setMax(maxHp)
		lifeBar.setValue(hp)
		lifeBar.flashFor(lifeBar.showSeconds)
	updateStatusUi()
	if hp <= 0:
		die()


## 塔被打爆。`hurt()` 与技能自损 `applySelfDamage()` **共用**这一条死亡流程，
## 保证两条路死出来的结果完全一致（爆炸 / 音效 / 归还格子 / 释放自己）。
## 注意顺序：ExplosionManage 把特效挂在 autoload 下，所以塔 free 掉特效还在；
## 音效也用 global_position 定位，必须在 queue_free 之前播。
func die() -> void:
	ExplosionManage.playExplosion(global_position, "heavy")
	SoundManage.playAt("tower_destroyed", global_position, -6.0, randf_range(0.95, 1.05))
	releaseGrid()
	queue_free()


## 恢复防御塔血量并限制在最大值内。返回**实际**回复了多少（满血时返回 0）。
##
## ⚠️ 为什么不直接复用 `hurt(负数)` —— 这是踩过的坑：
##    `hurt()` 里有一句 `hp -= int(max(0.0, ceil(actualDamage)))`，
##    那个 `max(0.0, ...)` 会把负伤害**夹成 0**，于是"负伤害＝治疗"根本不会生效
##    （实测传 -12 时血量纹丝不动）。而且 `hurt()` 开头还有
##    `if invincible: return` —— 无敌中的塔不该免疫治疗。
##    所以治疗单独走这个函数，语义也和 enemy.gd 的 addHp() 对齐。
func addHp(num: int) -> int:
	if num <= 0 or hp <= 0:
		return 0
	var before: int = hp
	hp = mini(maxHp, hp + num)
	if hp != before:
		if lifeBar:
			lifeBar.setMax(maxHp)
			lifeBar.setValue(hp)
			lifeBar.flashFor(lifeBar.showSeconds)
		updateStatusUi()
	return hp - before


## 把本塔占用的格子归还给关卡（出售 / 被打爆 都要走这一步）。
## ⚠️ 复用 Game.sellTower 那条通路会连带把"售价"也加给玩家 —— 打爆不该给钱，
##    所以这里单独发 towerGridReleased，只归还格子。
func releaseGrid() -> void:
	if coverGrid.is_empty():
		return
	Game.towerGridReleased.emit(coverGrid)
	coverGrid = []
	

func getMuzzlePosition() -> Vector2:
	if is_instance_valid(marker):
		return marker.global_position
	return global_position


# 开火特效：把炮口闪光转到目标方向，并播放一次 spark 动画
# spark 是挂在塔根节点下的（不跟着炮管转），所以这里要手动设一次朝向
# 没有配置 sparkPlayer 的塔（EMP / 特斯拉 / 激光 / 无人机基地）会自动跳过
func playMuzzleFlash(target_position: Vector2) -> void:
	if spark == null or sparkPlayer == null:
		return
	spark.rotation = (target_position - marker.global_position).angle()
	sparkPlayer.play("spark")

func onInputEvent(_viewport, _event, _shape_idx):
	#if event is InputEventMouseButton:
		#if event.is_pressed()&& event.button_index==MouseButton.MOUSE_BUTTON_LEFT:
			#selected=!selected
			#queue_redraw()
	if Input.is_action_just_pressed("click"):
		hideSelect()


# 出售前需要额外清理的塔（如无人机基地）覆写本方法
func onBeforeSell() -> void:
	pass


# 出售防御塔（由右侧信息面板的出售按钮调用）
func sell():
	if selected:
		hideSelect() # 出售前先取消选中，让右侧信息面板与地图状态同步清理
	onBeforeSell()
	# 出售：金币响声（先响再 free，free 之后位置就没了）
	#SoundManage.play_at("tower_sold", global_position, -2.0, randf_range(0.97, 1.05))
	SoundManage.play("tower_sold_b")
	# sellTower 负责"给钱 + 归还格子"；归还逻辑和被摧毁时共用同一条通路
	Game.towerSold.emit(sellingPrice, coverGrid)
	coverGrid = []
	queue_free()


# 请求修理：费用由 map 统一扣款，扣款成功后 map 会回调 apply_repair()
func requestRepair() -> bool:
	var cost: int = repairCost
	if cost <= 0:
		return false
	Game.towerRepaired.emit(cost, self)
	return true


# 实际把血量回满（由 map 在扣除费用后调用）
func applyRepair() -> void:
	if maxHp <= 0:
		return
	hp = maxHp
	updateStatusUi()
	# 回满血：能量充盈声
	# 素材已归一化过响度，不要再压（压了会像 tower_select 那次一样几乎听不见）
	SoundManage.playAt("tower_healed", global_position, 0.0)
	playRepairGlow()


# 修理完成后的闪光反馈（复用升级闪光 shader）
func playRepairGlow() -> void:
	var bm: ShaderMaterial = base.material as ShaderMaterial
	var tm: ShaderMaterial = turret.material as ShaderMaterial
	if bm:
		bm.set_shader_parameter("enable_flash", true)
	if tm:
		tm.set_shader_parameter("enable_flash", true)
	var tw: Tween = create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(stopGlow)


func _physics_process(delta: float) -> void:
	# 技能计时（冷却 / 限时生效 / 停摆 / 自损）每帧都要推进，
	# 所以放在最前面 —— 不能挂在"选中"之后，否则没选中的塔技能永远走不完。
	tickSkill(delta)
	if invincible: # 无敌期间
		invincibleLeft -= delta
		if invincibleLeft <= 0.0:
			setInvincibleVisual(false)
			
	if not selected:
		return
	radarSweepAngle = fmod(radarSweepAngle + delta * RADAR_SCAN_SPEED, TAU)
	queue_redraw()


func _draw():
	if not selected:
		return
	var radarColor: Color = Color(0.25, 0.75, 1.0, 1.0)
	# 画圈用**派生后的**射程：toggle 改了射程时，圈和真实碰撞体（applySight 写的那个）必须一致
	var scopeNow: float = effectiveScope()
	draw_circle(Vector2.ZERO, scopeNow, Color(radarColor.r, radarColor.g, radarColor.b, 0.12))
	draw_arc(Vector2.ZERO, scopeNow, 0.0, TAU, 64, Color(radarColor.r, radarColor.g, radarColor.b, 0.8), 2.0)
	for i in range(1, 4):
		var r = scopeNow * (i / 4.0)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(radarColor.r, radarColor.g, radarColor.b, 0.15), 1.0)
	var segments: int = 24
	var tailSpan: float = PI / 3.0
	for s in range(segments):
		var t = float(s) / segments
		var a = radarSweepAngle - tailSpan * t
		var alpha = (1.0 - t) * 0.5
		var nextA = radarSweepAngle - tailSpan * (float(s + 1) / segments)
		var p1 = Vector2(cos(a), sin(a)) * scopeNow
		var p2 = Vector2(cos(nextA), sin(nextA)) * scopeNow
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
		Vector2(cos(radarSweepAngle), sin(radarSweepAngle)) * scopeNow,
		Color(radarColor.r, radarColor.g, radarColor.b, 1.0),
		2.0
	)
