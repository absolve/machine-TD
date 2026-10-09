extends "res://script/tower/aircraft.gd"
## 无人机：4 个状态；待机/出击/返航用 **Seek / Flee**，攻击用**绕圈控制器**
##
## 思路照搬参考项目 `Demos/SeekFlee/` 的 Seeker：
##   它每帧只做三件事 ——
##     ① 算出**一个加速度**（seek 朝目标 / flee 背离目标）
##     ② velocity = (velocity + accel × delta).limit_length(speed_max)
##     ③ 位置 += velocity × delta，朝向跟速度走
##
## ★ 本次修正（旧版毛病：无人机飞到敌人旁边就**停住不动**，和 demo 的"一直在动"不一样）——
##   旧版在 ENGAGE_FAR / ENGAGE_NEAR 之间留了一段"死区"：进去就不给加速度、还额外加阻力，
##   于是只要在死区里减速到 0，它就**永远停在原地**（demo 里不存在这种情况）。
##   现在改成**绕圈盘旋**：切向速度一直喂满（保证一直在绕），径向再按半径误差纠偏，
##   于是它绕着敌人转圈，永远不会停下来。
##
## ★ 朝向：**只看速度方向**，不再刻意对着敌人（瞄准以后交给单独挂的炮塔）。
## ★ 开火：与飞行状态无关 —— 只要基地分配的目标还在**防御塔雷达范围**内就开火。
## ★ 每架按**编队序号**错开半径 + 绕圈速度（见 ENGAGE_RADIUS_STEP / ENGAGE_SPEED_STEP）——
##   一圈套一圈、快慢也有别，不会几架贴着同一条轨迹飞。
##
## 职责划分：
##   · **防御塔**：敌人侦测、无人机生成与回收、目标分配（见 drone_base.gd）
##   · **无人机**：只执行 assign() 收到的目标，不自己扫描敌人
##
## 四个状态：
##   IDLE     待机 —— 绕基地在自己那条轨道上飞
##   SORTIE   出击 —— **seek** 冲向目标
##   ATTACK   攻击 —— 绕目标盘旋（seek 圆圈上的前导点）
##   RETURN   返航 —— seek 回自己的轨道

enum State { IDLE, SORTIE, ATTACK, RETURN }

## ── 转向参数（对应 demo 里的 linear_speed_max / linear_accel_max）──
const SPEED_MAX := 260.0 # 最大速度
const ACCEL_MAX := 900.0 # 最大加速度
const turnSpeed := 12.0 # 机身转向速度（弧度/秒）

## ── 基地轨道：按防御塔雷达范围分层，每架一条，天然不重叠 ──
const ORBIT_RADIUS_RATIO := 0.40
const ORBIT_STEP_RATIO := 0.10
const ORBIT_MIN_STEP := 14.0
const ORBIT_FALLBACK_RADIUS := 90.0
const ORBIT_ANGULAR_SPEED := 1.15
const ORBIT_ARRIVE_DIST := 26.0 # 离轨道点这么近就算归位

## ── 交战：绕敌人盘旋 ──
## 这里直接把**加速度**算出来交给 apply（不是"期望速度" —— 绕圈必须显式算向心加速度）：
##   ① 切向：把"沿绕行方向的速率"往 orbit_speed 推 —— 这一项保证**永远在动**（旧版死区就是停在这的）
##   ② 径向：半径误差做弹簧 + 阻尼，把距离钉在 _attack_radius() 上
##   ③ 向心：补一项 v²/r —— 不补的话弹簧会被"离心"顶掉，实测半径会比目标明显偏大
##
## ★ 半径**和**绕圈速度都按编队序号错开：几架一起上是一圈套一圈、快慢也有别，
##   不会出现"几架贴着同一条轨迹飞"的情况（调下面两个 STEP 就能调开）。
const ENGAGE_RADIUS := 70.0 # 0 号无人机的盘旋半径（离敌人中心）
const ENGAGE_RADIUS_STEP := 50.0 # 每往后一号往外错开的量（0/1/2 → 70/120/170）
const ENGAGE_SPEED_BASE := 0.78 # 0 号无人机的绕圈速度（× SPEED_MAX）—— 圈越小要飞得越慢，才转得过来
const ENGAGE_SPEED_STEP := 0.11 # 每往后一号快一点（0/1/2 → 78%/89%/100%）
const ENGAGE_RADIAL_GAIN := 12.0 # 半径误差 → 径向加速度（1/s²）；要大于（绕圈角速度）² 才不会摆
const ENGAGE_RADIAL_DAMPING := 4.5 # 径向速度阻尼（1/s）
const ENGAGE_TANGENT_GAIN := 3.0 # 切向速度误差 → 切向加速度（1/s）
const ENGAGE_PANIC_DIST := 34.0 # 贴得比这还近 → 直接 flee 推开，防止从敌人身上穿过去
## 统一绕行方向（取反就整体换方向）
const ORBIT_SIGN := 1.0
## 出击→攻击 的切换距离
const ATTACK_ENTER := 210.0

## ── 弹匣：打满一匣冷却一会儿 ──
const MAX_BULLETS := 12
const BURST_COOLDOWN := 2.6
const FIRE_INTERVAL := 0.14
const MUZZLE_OFFSET := 16.0

## 尾迹
const TRAIL_MAX_POINTS := 26
const TRAIL_MIN_STEP := 5.0
const TRAIL_BREAK_DISTANCE := 150.0

const BULLET := preload("res://scene/bullet/gunBullet.tscn")

var homeBase = null
var slotIndex: int = 0
var slotCount: int = 1

var state: int = State.IDLE
var currentTarget = null

var velocity: Vector2 = Vector2.ZERO
var bulletDamage: int = 6

## 弹匣
var bulletsLeft: int = MAX_BULLETS
var reloadLeft: float = 0.0
var fireCooldown: float = 0.0

## 待机/返航用的轨道相位
var orbitPhase: float = 0.0
var orbitAngle: float = 0.0

var lastTrailPos: Vector2 = Vector2.ZERO

@onready var trail: Line2D = $Trail
@onready var shotSound = $ShotSound


# ============================================================
# 由塔调用
# ============================================================

func setupDrone(base, index: int, count: int) -> void:
	homeBase = base
	slotIndex = index
	slotCount = maxi(count, 1)
	orbitPhase = TAU * float(index) / float(slotCount)
	orbitAngle = orbitPhase
	var info: Dictionary = Game.towerInfo.get(Game.towerType.droneBase, {})
	bulletDamage = int(info.get("atk", bulletDamage))
	if trail:
		trail.clear_points()
	lastTrailPos = global_position


## 塔每帧调用：告诉这架无人机去打谁。target 传 null = 回去待机。
## _angle 是基地分配的包围方位角 —— 改成"绕圈盘旋"后不再需要它：
## 各架同向绕行时，进入轨道的相位差会天然保持，不会挤到一起。
func assign(target, _angle: float = 0.0) -> void:
	if target == null:
		if state != State.IDLE and state != State.RETURN:
			stateTo(State.RETURN)
		return
	if currentTarget != target or state == State.IDLE or state == State.RETURN:
		currentTarget = target
		stateTo(State.SORTIE)


func stateTo(s: int) -> void:
	state = s
	if s == State.ATTACK:
		# 新一轮交战：弹匣装满、冷却清零
		bulletsLeft = MAX_BULLETS
		reloadLeft = 0.0
		fireCooldown = 0.0


# ============================================================
# 状态实现
# ============================================================

# ---------- 待机：绕基地轨道 ----------
func doIdle(delta: float) -> void:
	steerTowards(baseOrbitPoint(), delta)


# ---------- 出击：seek 冲向目标 ----------
func doSortie(delta: float) -> void:
	if currentTarget == null:
		stateTo(State.RETURN)
		return
	if global_position.distance_to(currentTarget.global_position) <= ATTACK_ENTER:
		stateTo(State.ATTACK)
		return
	apply(seek(), delta)


# ---------- 攻击：**绕目标盘旋** ----------
##
## 加速度拆成三块（切向 + 径向弹簧 + 向心），见上面 ENGAGE_* 的注释。
## 切向那项保证它**一直在绕**；径向那项决定它**离敌人多远** —— 每架的目标半径都不一样。
func doAttack(delta: float) -> void:
	if currentTarget == null:
		stateTo(State.RETURN)
		return

	var toTarget: Vector2 = currentTarget.global_position - global_position
	var dist: float = toTarget.length()
	if dist <= ENGAGE_PANIC_DIST:
		# 贴脸了：直接反向推开，免得从敌人身上穿过去
		apply(flee(), delta)
		return

	var dir: Vector2 = toTarget / maxf(dist, 0.001) # 指向敌人（= 向心的方向）
	var tangent: Vector2 = Vector2(-dir.y, dir.x) * ORBIT_SIGN # 绕行方向
	var orbitSpeed: float = orbitSpeed()

	# 径向：半径误差弹簧 + 径向速度阻尼 + 向心加速度 v²/r（三项都取"向敌为正"）
	var radialAccel: float = (dist - attackRadius()) * ENGAGE_RADIAL_GAIN
	radialAccel -= velocity.dot(dir) * ENGAGE_RADIAL_DAMPING
	radialAccel += orbitSpeed * orbitSpeed / maxf(dist, 1.0)
	# 切向：把"沿绕行方向的速率"推到 orbit_speed —— 这项保证它一直在绕
	var tangentAccel: float = (orbitSpeed - velocity.dot(tangent)) * ENGAGE_TANGENT_GAIN
	apply((dir * radialAccel + tangent * tangentAccel).limit_length(ACCEL_MAX), delta)


# ---------- 返航：回到自己的轨道 ----------
func doReturn(delta: float) -> void:
	steerTowards(baseOrbitPoint(), delta)
	# ⚠️ 到达判定**不能拿"轨道点"比** —— 那个点自己在绕圈跑（约 110px/s），追进 26px 几乎不可能，
	#    旧版因此一直卡在 RETURN 切不回 IDLE（表现上没差，但状态是错的）。
	#    改成看"离基地的距离有没有落到本机那条轨道半径上"。
	if absf(global_position.distance_to(homeBase.global_position) - orbitRadius()) <= ORBIT_ARRIVE_DIST:
		stateTo(State.IDLE)


# ============================================================
# 转向行为（照搬 GSAISeek / GSAIFlee）
# ============================================================

## GSAISeek：朝目标方向的满加速度
func seek() -> Vector2:
	if currentTarget == null:
		return Vector2.ZERO
	return global_position.direction_to(currentTarget.global_position) * ACCEL_MAX


## GSAIFlee：背离目标方向的满加速度（只在贴脸时用一下，把无人机推开）
func flee() -> Vector2:
	if currentTarget == null:
		return Vector2.ZERO
	var dir: Vector2 = global_position.direction_to(currentTarget.global_position)
	return -dir * ACCEL_MAX


## 盘旋半径：**每架一号往外错开一大截** —— 几架一起上时是一圈套一圈，
## 而不是几架叠在同一条轨迹上（效果就是"每台离敌人的距离都不一样"）。
func attackRadius() -> float:
	return ENGAGE_RADIUS + ENGAGE_RADIUS_STEP * float(slotIndex)


## 绕圈速度：外圈半径大可以飞快点；内圈半径小，必须慢下来才转得过来
## （全速 260 时最小转弯半径 = SPEED_MAX² / ACCEL_MAX ≈ 75px，卡着这个值会一直擦地）。
func orbitSpeed() -> float:
	return SPEED_MAX * (ENGAGE_SPEED_BASE + ENGAGE_SPEED_STEP * float(slotIndex))


## 把加速度积分成速度（照搬 agent._apply_position_steering）
##   velocity = (velocity + accel × delta).limit_length(SPEED_MAX)
##   position += velocity × delta
func apply(accel: Vector2, delta: float) -> void:
	velocity = (velocity + accel * delta).limit_length(SPEED_MAX)
	global_position += velocity * delta


## 朝某个点飞：先按距离决定要不要减速，再把"期望速度 − 当前速度"当加速度交给 apply。
## 用于待机绕轨道 / 返航这种"要停到位"的场合 —— 纯 seek 会冲过头。
func steerTowards(targetPos: Vector2, delta: float) -> void:
	var toTarget: Vector2 = targetPos - global_position
	var dist: float = toTarget.length()
	if dist < 0.01:
		velocity = velocity.move_toward(Vector2.ZERO, ACCEL_MAX * delta)
		return
	var desiredSpeed: float = SPEED_MAX
	if dist < 110.0:
		desiredSpeed *= dist / 110.0
	var desiredVel: Vector2 = toTarget / dist * desiredSpeed
	apply((desiredVel - velocity).limit_length(ACCEL_MAX), delta)


## 朝向：**只看速度方向** —— 朝哪飞就朝哪，不再对着敌人。
## 瞄准以后由单独挂的炮塔负责，机身不用管（子弹方向仍然是朝目标的，见 fire）。
func faceVelocity(delta: float) -> void:
	if velocity.length_squared() <= 4.0:
		return
	rotation = rotate_toward(rotation, velocity.angle(), turnSpeed * delta)


# ============================================================
# 位置 / 开火
# ============================================================

## 本机专属轨道半径：按防御塔射程分层
func orbitRadius() -> float:
	if homeBase == null or not is_instance_valid(homeBase):
		return ORBIT_FALLBACK_RADIUS
	var scope: float = float(homeBase.radarScope)
	if scope <= 0.0:
		scope = ORBIT_FALLBACK_RADIUS
	var inner: float = scope * ORBIT_RADIUS_RATIO
	var step: float = maxf(scope * ORBIT_STEP_RATIO, ORBIT_MIN_STEP)
	return inner + step * float(slotIndex)


func baseOrbitPoint() -> Vector2:
	return homeBase.global_position + Vector2.from_angle(orbitAngle) * orbitRadius()


## 开火判定：**只看基地分配的目标还在不在防御塔雷达范围内** ——
## 与无人机自己飞到哪、处于什么状态都无关，敌人进圈就能打。
func tryFire() -> void:
	if fireCooldown > 0.0 or reloadLeft > 0.0:
		return
	if currentTarget == null or not is_instance_valid(currentTarget):
		return
	if homeBase.global_position.distance_to(currentTarget.global_position) > float(homeBase.radarScope):
		return
	fire()
	fireCooldown = FIRE_INTERVAL
	bulletsLeft -= 1
	if bulletsLeft <= 0:
		reloadLeft = BURST_COOLDOWN


## 子弹从机头（速度正前方）出膛，但**方向仍然指向目标** ——
## 机身只负责飞，瞄准交给枪口角度；将来换成单独炮塔瞄准也一样。
func fire() -> void:
	if currentTarget == null or not is_instance_valid(currentTarget):
		return
	if shotSound:
		shotSound.play()
	var b = BULLET.instantiate()
	b.global_position = global_position + Vector2.from_angle(rotation) * MUZZLE_OFFSET
	b.angle = (currentTarget.global_position - global_position).angle()
	b.sourceTower = homeBase
	b.damage = bulletDamage
	Game.addObj(b)


# ============================================================
# 尾迹
# ============================================================

func updateTrail() -> void:
	if trail == null:
		return
	var moved: float = global_position.distance_to(lastTrailPos)
	if moved > TRAIL_BREAK_DISTANCE:
		trail.clear_points()
		lastTrailPos = global_position
		trail.add_point(global_position)
		return
	if moved < TRAIL_MIN_STEP:
		return
	lastTrailPos = global_position
	trail.add_point(global_position)
	while trail.get_point_count() > TRAIL_MAX_POINTS:
		trail.remove_point(0)


# ============================================================
# 主循环（内置虚函数放最后）
# ============================================================

func _physics_process(delta: float) -> void:
	if homeBase == null or not is_instance_valid(homeBase):
		queue_free()
		return
	if currentTarget != null and not is_instance_valid(currentTarget):
		currentTarget = null
		if state == State.SORTIE or state == State.ATTACK:
			stateTo(State.RETURN)

	# 计时器
	fireCooldown = maxf(fireCooldown - delta, 0.0)
	if reloadLeft > 0.0:
		reloadLeft = maxf(reloadLeft - delta, 0.0)
		if reloadLeft <= 0.0:
			bulletsLeft = MAX_BULLETS
	orbitAngle = fmod(orbitAngle + ORBIT_ANGULAR_SPEED * delta, TAU)

	match state:
		State.IDLE:
			doIdle(delta)
		State.SORTIE:
			doSortie(delta)
		State.ATTACK:
			doAttack(delta)
		State.RETURN:
			doReturn(delta)

	faceVelocity(delta)
	tryFire()
	updateTrail()
