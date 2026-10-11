extends "res://script/tower/tower.gd"
## 移动机甲（后勤单位，见 feature_design.md §十）。
##
## 它**不是战斗塔**：不杀敌、不升级，用一束激光修复附近残血的我方防御塔。
##
## ── 三个关键设计 ──
##
## ① **"维修量"就是 atk**
##    机甲不杀敌，它的 `atk`（towerInfo 里配的）在它身上代表**每次激光修复多少血**。
##    治疗走 `Tower.addHp()`。
##    ⚠️ 一度想用"对塔造成负伤害"来实现（更省接口），但 `Tower.hurt()`
##       内部的 `max(0.0, ...)` 会把负伤害夹成 0，实际不生效 —— 详见 fireRepairBeam()。
##
## ② **机甲之间不会叠在一起**
##    机甲和普通塔一样占用格子（`map.gd::placeTower` 里 `level.addOccupiedArea(coverGrid)`），
##    而建造校验 `base_level.canPlace()` 已经会拒绝 `occupiedArea` 里的格子。
##    所以"不能叠"是**格子系统天然给的**，这里不需要额外写碰撞检测。
##
## ③ **周期性回血**
##    独立的 `selfHealTimer`，与激光脉冲`Delay`互不干扰 —— 两件事周期不同，
##    共用一个 Timer 会互相打断。

## 自身回血间隔（秒）
@export var selfHealInterval: float = 6.0
## 每次回血量（占最大血量的百分比，0~1）
@export var selfHealRatio: float = 0.06

@onready var selfHealTimer: Timer = $SelfHealTimer

## ── 移动（见 feature_design.md §10.4）──
## 移动速度（像素/秒）
@export var moveSpeed: float = 140.0
## 到达判定的容差（像素）。小于这个距离就吸附到格中心并结束移动。
@export var arriveEpsilon: float = 2.0

## ── 回收（见 feature_design.md §十一 + §10.5）──
## 回收激光射程（像素）。
## 比维修射程（radarScope）远一点：残骸都掉在**敌人路线上**，
## 射程长一点能让机甲停在离路线更远的地方作业，观感更安全（§10.3 同款理由）。
@export var salvageScope: float = 220.0
## 回收一坨残骸需要多少秒（持续作业）
@export var salvageSeconds: float = 1.2

## 当前正在回收的残骸（null = 没在回收）
var salvageTarget: Node2D = null
## 对当前残骸已投入的作业时间（秒）
var salvageElapsed: float = 0.0
## 回收作业是否进行中（_draw 决定画不画回收激光）
var salvageBeamOn: bool = false

## 移动目标（世界坐标）。仅在 moving 为 true 时有效。
var moveTarget: Vector2 = Vector2.ZERO
## 是否正在移动。移动中**不作业**（避免"边走边吸"），到达后重新索敌。
var moving: bool = false
## 上一帧是否在移动，用来检测"移动刚结束"这个边沿。
var wasMoving: bool = false

## 当前被激光锁定的**我方防御塔**（null = 没有需要修的）
var repairTarget: Tower = null
## 激光是否正在照射（_draw 用；没有目标时不画，避免留残影）
var beamOn: bool = false
## 机体爬行动画相位
var crawlPhase: float = 0.0
## 激光脉冲是否正在冷却。
##
## ⚠️ 为什么不能只靠基类的 `canShot`：`canShot` 由 `Delay` 超时回调置回 true，
##    而 `_physics_process` 每帧都跑。如果写成
##        if beamOn and canShot: fire(); canShot = false; delayTimer.start()
##    那么在**从没超时之前**，只要 beamOn 还是 true，下一帧又会进 `if canShot` ——
##    不对，canShot 那时是 false。真正会出事的是"每帧无条件 start()"：
##        if beamOn: if canShot: fire(); canShot=false; delayTimer.start()
##    这样每帧都 restart() 计时器，它**永远等不到超时**，canShot 永远回不到 true，
##    结果就是"只修了一次"（实测卡死在 canShot=false）。
##    所以这里自己立一个"冷却中"标志，start() 只在开始冷却那一刻调一次。
var pulseCooldown: bool = false
## 爬行动画速度（帧/秒）。只在"身体动画"上，炮塔动画另算。
const CRAWL_FPS := 8.0
## 爬行循环音的音量（dB）。比开火音轻一档 —— 它是**持续**的底噪，
## 调到和一次性音效一样响会很快让人烦。
const CRAWL_SOUND_DB := -11.0
## 部署动画（initTime）放完了没有。
## ⚠️ 基类 `_ready()` 里 `set_physics_process(false)`，要等 `init()` 才打开；
##    这里再立一个自己的标志，避免依赖基类时序（laser_tower.gd 同款做法）。
var deployed: bool = false


func _ready() -> void:
	super._ready()
	# 机甲自己成一个组：建造数量上限靠它统计（map.gd::placeTower）
	add_to_group("mech")
	if selfHealTimer != null:
		selfHealTimer.wait_time = selfHealInterval
		selfHealTimer.timeout.connect(onSelfHealTimeout)
		selfHealTimer.start()
	# Delay 超时同时解掉"脉冲冷却"锁（基类的 onDelayTimeout 负责 canShot）
	if delayTimer != null:
		delayTimer.timeout.connect(onPulseReady)


func init() -> void:
	super.init()
	deployed = true
	# 待机停靠：身体与炮塔的帧动画都停在第 1 帧。
	# 场景里 base/turret 都带 autoplay，不主动 stop 的话静止状态下它们会自己播 ——
	# 那样"只在移动时爬"就白写了。
	if base != null:
		base.stop()
		base.frame = 0
	if turret != null:
		turret.stop()
		turret.frame = 0


## 周期性自愈。满血时不播特效、不重复刷。
func onSelfHealTimeout() -> void:
	if hp <= 0 or hp >= maxHp:
		return
	var amount: int = maxi(1, int(round(float(maxHp) * selfHealRatio)))
	hp = mini(maxHp, hp + amount)
	if lifeBar:
		lifeBar.value = hp
	updateStatusUi()
	# 复用现成的"治疗"音；位置音效，听得出发自哪台机甲
	SoundManage.playAt("tower_healed", global_position, -8.0, randf_range(0.95, 1.05))


## 找一台**残血**的我方防御塔，坐标最近的优先。
##
## 为什么要"最近的"而不是"第一个找到的"：机甲一次只照一台，
## 用最近的那台观感上才像"它够得着所以先修它"。
## 排除自己 —— 机甲不修自己（自愈走 selfHealTimer，是另一套机制）。
func pickRepairTarget() -> Tower:
	var best: Tower = null
	var bestDist: float = INF
	for t in get_tree().get_nodes_in_group("tower"):
		if t == self or not is_instance_valid(t):
			continue
		if not (t is Tower):
			continue
		# 满血的不用修
		if t.hp >= t.maxHp:
			continue
		var d: float = global_position.distance_to(t.global_position)
		# 超出激光作用半径的够不着
		if d > radarScope:
			continue
		if d < bestDist:
			bestDist = d
			best = t
	return best


## 发一次激光脉冲：给锁定的塔回血。
##
## ⚠️ **不能**用 `repairTarget.hurt(-atk)` 来实现"负伤害＝治疗" —— 试过，不生效：
##    `tower.hurt()` 里是 `hp -= int(max(0.0, ceil(actualDamage)))`，
##    那个 `max(0.0, ...)` 会把负伤害夹成 0，结果血量纹丝不动（实测）。
##    而且 `hurt()` 开头 `if invincible: return`，治疗也不该被无敌挡掉。
##    所以治疗走 `tower.addHp()`（与 enemy.gd 的 addHp 同名同义）。
##
## `atk` 仍然是**维修量**：机甲不造成伤害，它的"攻击力"就是它的治疗量。
func fireRepairBeam() -> void:
	if repairTarget == null or not is_instance_valid(repairTarget):
		return
	var healed: int = repairTarget.addHp(atk)
	if healed <= 0:
		# 刚好在这一帧被别人修满了 / 已经满血：不播特效，避免空放
		return
	playMuzzleFlash(repairTarget.global_position)
	playMuzzleFx()
	SoundManage.playAt("hit_hard", repairTarget.global_position, -16.0, randf_range(1.05, 1.25))


## 炮口粒子放在**炮口**（marker 的世界坐标）并重播。
##
## ⚠️ 顺序：先挪位置再 restart/emitting —— 反过来的话新粒子会从**旧位置**冒出来，
##    激光已经从 A 打到 B 了、炮口火花还在 A（laser_tower.gd 的注释里记过这个坑）。
func playMuzzleFx() -> void:
	if muzzleFx == null:
		return
	muzzleFx.global_position = getMuzzlePosition()
	muzzleFx.restart()
	muzzleFx.emitting = true
	muzzleBurstLeft = MUZZLE_BURST_SECONDS


## 炮口粒子的收尾：喷够 MUZZLE_BURST_SECONDS 就关掉，不要一直挂在炮口。
func updateMuzzleBurst(delta: float) -> void:
	if muzzleBurstLeft <= 0.0:
		return
	muzzleBurstLeft -= delta
	if muzzleBurstLeft <= 0.0 and muzzleFx != null:
		muzzleFx.emitting = false


## 炮塔转速（弧度/秒）。
##
## ⚠️ 开火激光不会自己让炮塔转 —— 必须显式写 `turret.rotation`。
##    基类唯一的旋转来源是 `player` 里那个 "fire" 后坐动画（机枪/加农/火箭有），
##    而机甲走的是激光那条路（状态标志 + _draw 画线），既没有 "fire" 动画、
##    也没有人写 rotation，所以之前炮塔是**死的**，激光从炮口里斜着射出来。
##
## 用插值而不是直接赋值：激光是持续的，炮塔猛地跳过去很出戏；
## 平滑跟过去才像"伺服在随动"。数值取 10 与基类 rotationSpeed 一致。
const TURRET_TURN_SPEED := 10.0


## 把炮塔转向当前作业目标；没有目标时保持不动。
##
## 用 `lerp_angle` 而不是 `lerp`：角度是环形的，直接插值会在 ±π 处绕远路
## （炮塔会突然反着转一大圈）。
func updateTurretAim(delta: float) -> void:
	if turret == null:
		return
	var tgt: Node2D = null
	if repairTarget != null and is_instance_valid(repairTarget):
		tgt = repairTarget
	elif salvageBeamOn and salvageTarget != null and is_instance_valid(salvageTarget):
		tgt = salvageTarget
	if tgt == null:
		return
	var want: float = (tgt.global_position - global_position).angle()
	# 炮塔贴图朝 +X（与其它塔同一套约定，见 art_style.md §6）
	turret.rotation = lerp_angle(turret.rotation, want, TURRET_TURN_SPEED * delta)


## 炮口粒子：**就在本场景里**（MuzzleFx），开火时挪到炮口重播一次。
##
## 与激光塔（laser_tower.gd::playMuzzleFx）同一套做法，理由也一样：
## 一秒要放好几次，反复 instantiate 单独的场景很浪费；而且粒子是塔的一部分，
## 被卖掉时会跟着销毁，不会残留。
@onready var muzzleFx: CPUParticles2D = get_node_or_null("MuzzleFx") as CPUParticles2D

## 炮口粒子还要喷多久（秒）。开火那一帧置为 MUZZLE_BURST_SECONDS，然后倒数。
##
## 为什么不是"每帧 restart()"：`restart()` 会清掉已有粒子重新喷，每帧调用等于
## 粒子永远出不去（看着像没效果）。所以只在开火那一刻 restart 一次，
## 之后让它自然喷完 —— 这个倒计时就是"关掉 emitting"的时机。
var muzzleBurstLeft: float = 0.0
const MUZZLE_BURST_SECONDS := 0.16


## 爬行音：只在移动时循环响（与激光塔的 loop 用法同一条通路）。
##
## ⚠️ 三条不能省：
##   ① 必须防重复 startLoop：SoundManage 里"同一个 key 已在响就什么都不做"，
##      但这里仍然只在**状态翻转**时调一次 —— 每帧调用等于每帧做一次字典查询，
##      而且日志里会把这条路径刷爆。
##   ② 塔被卖掉 / 摧毁 / 关卡结束时一定要 stopLoop，否则那台机甲的爬行音会一直响下去
##      （挂在 autoload 下，不随塔的 queue_free 消失）。所以 _exit_tree 里要收尾。
##   ③ 到达后立刻停，否则"站着的机甲还在响轮子声"。
var crawlSoundOn: bool = false


func updateCrawlSound() -> void:
	if moving == crawlSoundOn:
		return
	crawlSoundOn = moving
	if crawlSoundOn:
		SoundManage.startLoop("mech_crawl", "mech_crawl", CRAWL_SOUND_DB)
	else:
		SoundManage.stopLoop("mech_crawl")


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not deployed:
		return

	# ── 机体动画：**只在移动时才爬** ──
	# 站着不动的机甲不该一直迈腿：它是"待机停靠"的后勤单位。
	# 所以移动时推进爬行帧，静止时**帧位不动**（保留最后一帧的姿势）。
	if moving:
		crawlPhase = fmod(crawlPhase + delta * CRAWL_FPS, 4.0)
		if base != null:
			base.frame = int(crawlPhase) % 4
	# 炮塔那套微动同理：只有移动时转，静止就定住
	if turret != null and turret.sprite_frames != null:
		if moving:
			turret.play("default")
		else:
			turret.stop()
	# 炮塔朝向作业目标（维修 / 回收）
	updateTurretAim(delta)

	# 移动优先于一切作业：移动中不索敌、不发射（§10.4「移动中不能作业」）
	updateMovement(delta)
	updateCrawlSound()
	updateMuzzleBurst(delta)
	if moving:
		# 记住"这一帧在移动"，下一帧到达时才能清掉上一帧残留的激光
		wasMoving = true
		repairTarget = null
		beamOn = false
		# 移动中不作业：回收也一起中断（§10.4「移动中不能作业」）
		abortSalvage()
		queue_redraw()
		return
	if wasMoving:
		# 刚到达：清掉移动前那一帧的激光，下面会立刻重新索敌
		wasMoving = false
		beamOn = false
		queue_redraw()

	# 重新索敌：目标可能被修满 / 被卖掉 / 已被摧毁
	repairTarget = pickRepairTarget()
	beamOn = repairTarget != null

	# 索敌优先级（§10.5）：**先修塔、再收残骸**。
	# 理由：塔被打爆是不可逆损失，残骸只是钱；而且玩家想让机甲专注回收时，
	# 把残骸放得更近就行（下面回收是按距离挑的），不必再做一层手动优先级 UI。
	if beamOn:
		# 有塔要修 -> 回收立即中断（不保留进度，切回来重新算）
		abortSalvage()
	else:
		updateSalvage(delta)

	# 脉冲节流：**只有不在冷却中**才可能开火。
	# ⚠️ delayTimer.start() 必须只调一次（进入冷却那一刻）——
	#    每帧都 start() 会把计时器一直重置，它永远不超时，canShot 也就永远回不到 true。
	#    所以这里用 pulseCooldown 自己兜住，而不是依赖 canShot 当"是否在冷却"用。
	if not pulseCooldown:
		if beamOn and canShot:
			fireRepairBeam()
			canShot = false
		# 无论这一帧有没有真的开火，只要还在冷却窗口内就不重复 start()
		if not canShot:
			pulseCooldown = true
			delayTimer.start()

	# ★ 无论有没有目标都要重绘：
	#   目标消失时若不重绘，上一帧的激光就永远留在画布上（laser_tower.gd 踩过这个坑）。
	queue_redraw()


## 找一坨射程内**最近的**残骸。
##
## 距离优先（§10.5）：玩家把残骸放得离机甲更近，就能让它先收那一坨 ——
## 不再额外做"手动指定优先级"的 UI。
func pickSalvageTarget() -> Node2D:
	var best: Node2D = null
	var bestDist: float = INF
	for w in get_tree().get_nodes_in_group("wreckage"):
		if not is_instance_valid(w) or not (w is Node2D):
			continue
		var d: float = global_position.distance_to((w as Node2D).global_position)
		if d > salvageScope:
			continue
		if d < bestDist:
			bestDist = d
			best = w
	return best


## 推进回收作业：累计时长，够了就收走。
##
## ⚠️ 进度写在**残骸自己**身上（`salvageProgress`），不是机甲身上 ——
##    进度环要画在残骸头顶（§11.5），写在残骸上它自己就能重绘，
##    机甲换目标时也不用先去把旧目标的进度清干净（abortSalvage 会清）。
func updateSalvage(delta: float) -> void:
	var t: Node2D = pickSalvageTarget()
	if t == null:
		abortSalvage()
		return
	if t != salvageTarget:
		# 换了目标：旧的重头再来
		abortSalvage()
		salvageTarget = t
		salvageElapsed = 0.0
	salvageBeamOn = true
	salvageElapsed += delta
	var ratio: float = clampf(salvageElapsed / maxf(0.05, salvageSeconds), 0.0, 1.0)
	if "salvageProgress" in salvageTarget:
		salvageTarget.set("salvageProgress", ratio)
		salvageTarget.set("salvaging", true)
		salvageTarget.queue_redraw()
	if ratio >= 1.0:
		# 收完：钱由残骸自己按它的 scrapValue 入账（见 wreckage.gd::collect）
		var done: Node2D = salvageTarget
		abortSalvage()
		if is_instance_valid(done) and done.has_method("collect"):
			done.call("collect")
			SoundManage.playAt("tower_healed", done.global_position, -10.0, 1.15)


## 中断回收（换目标 / 切去修塔 / 开始移动都要调）。
## 会把残骸身上的进度与"正在被回收"标记清掉，避免它卡在"永远在回收中"而不淡出。
func abortSalvage() -> void:
	if salvageTarget != null and is_instance_valid(salvageTarget):
		if "salvageProgress" in salvageTarget:
			salvageTarget.set("salvageProgress", 0.0)
			salvageTarget.set("salvaging", false)
			salvageTarget.queue_redraw()
	salvageTarget = null
	salvageElapsed = 0.0
	salvageBeamOn = false


## 冷却结束：复位，允许下一发脉冲。
## Delay 的 timeout 在基场景里已经连到基类的 onDelayTimeout()（它会把 canShot 置回 true），
## 这里再连一个自己的，只负责解掉 pulseCooldown 这层锁。
func onPulseReady() -> void:
	pulseCooldown = false


## ── 移动 ──
##
## 把机甲派到某个格子。返回是否接受这条指令 —— 被拒绝时**不改变任何状态**。
##
## 拒绝的三种情况（§10.2 / §10.4）：
##   · 目标格压在敌人路线上 —— 这是机甲的核心约束，不是 bug
##   · 目标格已经被别的塔/机甲占用
##   · 目标格在地图外（点得再远也只能开到图内）
## 三种都弹一次提示，让玩家知道"为什么点不动"。
func commandMoveTo(grid: Vector2i) -> bool:
	var currLevel = Game.map.level if Game.map != null else null
	if currLevel == null:
		return false
	if not isInsideMap(grid):
		Game.map.addNotice(tr("_MechCannotLeaveMap"))
		return false
	if currLevel.isRouteCell(grid):
		Game.map.addNotice(tr("_MechCannotEnterRoute"))
		return false
	if grid in currLevel.occupiedArea:
		# 已经被占用的格子（可能是别的塔/机甲）
		Game.map.addNotice(tr("_MechCellOccupied"))
		return false
	moveTarget = Vector2((grid.x * StageData.TileSize + StageData.TileSize / 2),
		(grid.y * StageData.TileSize + StageData.TileSize / 2))
	moving = true
	# ★ 立刻释放当前占用的格子，而不是等到到达才换。
	#   机甲已经离开那一格了，若继续占着，这一整段路程里玩家都无法在它**身后**
	#   建塔（"我明明看着它走了"）—— 实测就是这个问题。
	#   到达时会由 claimCurrentGrid() 占住新格；移动途中 coverGrid 为空，
	#   所以 canPlace 对沿途格子是放行的（机甲本来就能穿过空地）。
	releaseCurrentGrid()
	return true


## 目标格是否在图内。
##
## "地图任何地方"指的是**游戏画面范围内**，不是无限远 —— 不拦的话玩家点屏幕外
## 就能把机甲开进地图边界之外的虚空里，再也点不回来（那格永远不会被任何格子逻辑碰到）。
## 用视口尺寸换算成格子数，而不是写死 30×17，改分辨率时不用跟着改。
##
## ⚠️ 用 `get_viewport().get_visible_rect()`：`Node2D` 上**没有** `get_viewport_rect()`
##    （那是 Control 的），直接调会 Parse Error: Function not found in base self。
func isInsideMap(grid: Vector2i) -> bool:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var t: int = StageData.TileSize
	return grid.x >= 0 and grid.y >= 0 \
		and grid.x < int(ceil(vp.x / float(t))) \
		and grid.y < int(ceil(vp.y / float(t)))


## 归还当前占用的格子（移动开始时调；到达时由 claimCurrentGrid 占新格）
func releaseCurrentGrid() -> void:
	var currLevel = Game.map.level if Game.map != null else null
	if currLevel == null:
		return
	if not coverGrid.is_empty():
		currLevel.removeOccupiedArea(coverGrid)
		coverGrid = [] as Array[Vector2i]


## 每帧推进移动。到达后吸附到格中心，并把占用格从旧格换到新格。
func updateMovement(delta: float) -> void:
	if not moving:
		return
	var to: Vector2 = moveTarget - position
	var dist: float = to.length()
	var step: float = moveSpeed * delta
	if dist <= maxf(arriveEpsilon, step):
		# 到达：吸附到格中心（走直线可能差几个像素，吸附后格子对齐才不会漂）
		position = moveTarget
		moving = false
		claimCurrentGrid()
		return
	position += to / dist * step


## 把"占用的格子"更新到当前所在格：先归还旧格，再占住新格。
##
## ⚠️ 顺序不能省：只占不还的话，机甲开走后原地那格**永远建不了东西**；
##    只还不占的话，别的机甲可以开进同一格 —— 两者都会让"不能叠"失效。
func claimCurrentGrid() -> void:
	var currLevel = Game.map.level if Game.map != null else null
	if currLevel == null:
		return
	var grid: Vector2i = Vector2i(
		floori(position.x / StageData.TileSize),
		floori(position.y / StageData.TileSize))
	if coverGrid.size() == 1 and coverGrid[0] == grid:
		return  # 还在同一格，不用动
	if not coverGrid.is_empty():
		currLevel.removeOccupiedArea(coverGrid)
	coverGrid = [grid] as Array[Vector2i]
	currLevel.addOccupiedArea(coverGrid)


func _draw() -> void:
	super._draw()
	var origin: Vector2 = to_local(getMuzzlePosition())
	# 维修激光
	if beamOn and repairTarget != null and is_instance_valid(repairTarget):
		drawLaserBeam(origin, to_local(repairTarget.global_position))
	# 回收激光
	if salvageBeamOn and salvageTarget != null and is_instance_valid(salvageTarget):
		drawLaserBeam(origin, to_local(salvageTarget.global_position))


## 激光样式：单条 2px 线，亮度每帧随机抖动，读起来就是"能量束在跳"。
## 机甲本来就每帧 queue_redraw()，所以抖动会自然出现，不需要额外做什么。
##
## **黄色**（`#FFC61A` 安全黄）。注意这里和激光塔的红色不同：
## art_style.md §6 的铁律是"黄 = 我方、锈红 = 敌方"，而机甲是**我方后勤单位**，
## 用敌方的红会让人误读成"它在攻击那个塔"。所以机甲改成我方黄。
##
## 维修与回收共用这一套 —— 两者的区别只在"照的是塔还是残骸"。
func drawLaserBeam(start: Vector2, end: Vector2) -> void:
	if start.distance_squared_to(end) <= 0.0001:
		return
	# 在安全黄的基础色上做亮度抖动：G/B 通道按同一比例缩放，
	# 这样抖动时**色相不变**（只变亮暗），不会一会偏橙一会偏绿。
	var brightness: float = randf_range(0.72, 1.0)
	var baseColor: Color = Color(1.0, 0.776, 0.102)   # #FFC61A
	var laserColor: Color = Color(
		clampf(baseColor.r * brightness + 0.12, 0.0, 1.0),
		clampf(baseColor.g * brightness, 0.0, 1.0),
		clampf(baseColor.b * brightness, 0.0, 1.0),
		1.0)
	draw_line(start, end, laserColor, 2.0, true)


## 塔被卖掉或摧毁时一定要收尾：
##   · 中断回收，否则那坨残骸会卡在 salvaging=true 永不淡出
##   · 停掉爬行循环音，否则它挂在 autoload 下会一直响下去（不随本节点销毁）
func _exit_tree() -> void:
	abortSalvage()
	SoundManage.stopLoop("mech_crawl")
