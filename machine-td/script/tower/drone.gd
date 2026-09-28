extends "res://script/tower/aircraft.gd"
## 无人机：4 个状态，飞行只用 **Seek / Flee 两个转向行为**
##
## 思路直接照搬参考项目 `Demos/SeekFlee/` 的 Seeker：
##   它每帧只做三件事 ——
##     ① 算出**一个加速度**（seek 朝目标 / flee 背离目标）
##     ② velocity = (velocity + accel × delta).limit_length(speed_max)
##     ③ 位置 += velocity × delta，朝向跟速度走
##   整个"战斗机动"就是**在 seek 和 flee 之间切** —— 没有弹簧、没有半径约束、
##   没有任何闭环调参，所以既不会僵死，也不会摆。
##
## 职责划分：
##   · **防御塔**：敌人侦测、无人机生成与回收、目标分配（见 drone_base.gd）
##   · **无人机**：只执行 assign() 收到的目标，不自己扫描敌人
##
## 四个状态：
##   IDLE     待机 —— 绕基地在自己那条轨道上飞
##   SORTIE   出击 —— **seek** 冲向目标
##   ATTACK   攻击 —— 太远 seek、太近 flee，在目标附近来回穿插并开火
##   RETURN   返航 —— seek 回自己的轨道

enum State { IDLE, SORTIE, ATTACK, RETURN }

## ── 转向参数（对应 demo 里的 linear_speed_max / linear_accel_max）──
const SPEED_MAX := 260.0        # 最大速度
const ACCEL_MAX := 900.0        # 最大加速度
const TURN_SPEED := 12.0        # 机身转向速度（弧度/秒）

## ── 基地轨道：按防御塔雷达范围分层，每架一条，天然不重叠 ──
const ORBIT_RADIUS_RATIO := 0.40
const ORBIT_STEP_RATIO := 0.10
const ORBIT_MIN_STEP := 14.0
const ORBIT_FALLBACK_RADIUS := 90.0
const ORBIT_ANGULAR_SPEED := 1.15
const ORBIT_ARRIVE_DIST := 26.0   # 离轨道点这么近就算归位

## ── 交战距离：这两个值决定"靠近又远离"的幅度 ──
const ENGAGE_FAR := 150.0        # 比这远 → seek（冲过去）
const ENGAGE_NEAR := 78.0        # 比这近 → flee（拉出去）
								 # 中间是**死区**：不给加速度，靠惯性滑行穿插
## 出击→攻击 的切换距离
const ATTACK_ENTER := 190.0

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

var home_base = null
var slot_index := 0
var slot_count := 1

var state: int = State.IDLE
var current_target = null

var velocity := Vector2.ZERO
var bullet_damage := 6

## 弹匣
var bullets_left := MAX_BULLETS
var reload_left := 0.0
var fire_cooldown := 0.0

## 待机/返航用的轨道相位
var _orbit_phase := 0.0
var _orbit_angle := 0.0

var _last_trail_pos := Vector2.ZERO

@onready var trail: Line2D = $trail
@onready var shotSound = $shotSound


# ============================================================
# 由塔调用
# ============================================================

func setup_drone(base, index: int, count: int) -> void:
	home_base = base
	slot_index = index
	slot_count = maxi(count, 1)
	_orbit_phase = TAU * float(index) / float(slot_count)
	_orbit_angle = _orbit_phase
	var info: Dictionary = Game.towerInfo.get(Game.towerType.droneBase, {})
	bullet_damage = int(info.get("atk", bullet_damage))
	if trail:
		trail.clear_points()
	_last_trail_pos = global_position


## 塔每帧调用：告诉这架无人机去打谁。target 传 null = 回去待机。
func assign(target, _angle: float = 0.0) -> void:
	if target == null:
		if state != State.IDLE and state != State.RETURN:
			_state_to(State.RETURN)
		return
	if current_target != target or state == State.IDLE or state == State.RETURN:
		current_target = target
		_state_to(State.SORTIE)


func _state_to(s: int) -> void:
	state = s
	if s == State.ATTACK:
		# 新一轮交战：弹匣装满、冷却清零
		bullets_left = MAX_BULLETS
		reload_left = 0.0
		fire_cooldown = 0.0


# ============================================================
# 主循环
# ============================================================

func _physics_process(delta: float) -> void:
	if home_base == null or not is_instance_valid(home_base):
		queue_free()
		return
	if current_target != null and not is_instance_valid(current_target):
		current_target = null
		if state == State.SORTIE or state == State.ATTACK:
			_state_to(State.RETURN)

	# 计时器
	fire_cooldown = maxf(fire_cooldown - delta, 0.0)
	if reload_left > 0.0:
		reload_left = maxf(reload_left - delta, 0.0)
		if reload_left <= 0.0:
			bullets_left = MAX_BULLETS
	_orbit_angle = fmod(_orbit_angle + ORBIT_ANGULAR_SPEED * delta, TAU)

	match state:
		State.IDLE:
			_do_idle(delta)
		State.SORTIE:
			_do_sortie(delta)
		State.ATTACK:
			_do_attack(delta)
		State.RETURN:
			_do_return(delta)

	_face_velocity(delta)
	_update_trail()


# ---------- 待机：绕基地轨道 ----------
func _do_idle(delta: float) -> void:
	_steer_towards(_base_orbit_point(), delta)


# ---------- 出击：seek 冲向目标 ----------
func _do_sortie(delta: float) -> void:
	if current_target == null:
		_state_to(State.RETURN)
		return
	if global_position.distance_to(current_target.global_position) <= ATTACK_ENTER:
		_state_to(State.ATTACK)
		return
	_apply(_seek(), delta)


# ---------- 攻击：**远 seek / 近 flee**，中间死区靠惯性穿插 ----------
##
## 这就是参考项目 SeekFlee 的做法：只在 seek 和 flee 之间切，不看别的。
##   · 比 ENGAGE_FAR 远  → seek：朝目标加速，冲过去
##   · 比 ENGAGE_NEAR 近 → flee：背离目标加速，拉出来
##   · 两者之间          → 不给加速度，带着惯性滑过去（自然就"擦身而过"）
## 冲近 → 被推开 → 再冲近 …… 于是形成"靠近又远离"的盘旋。
func _do_attack(delta: float) -> void:
	if current_target == null:
		_state_to(State.RETURN)
		return

	var dist := global_position.distance_to(current_target.global_position)

	if dist > ENGAGE_FAR:
		_apply(_seek(), delta)
	elif dist < ENGAGE_NEAR:
		_apply(_flee(dist), delta)
	else:
		# 死区：只保留惯性 + 轻微阻力，让它平滑滑过而不是急停
		velocity = velocity.move_toward(Vector2.ZERO, ACCEL_MAX * 0.12 * delta)
		global_position += velocity * delta

	# 开火：距离够近、有子弹、不在冷却
	if reload_left <= 0.0 and fire_cooldown <= 0.0 and dist <= ENGAGE_FAR * 1.5:
		_fire()
		fire_cooldown = FIRE_INTERVAL
		bullets_left -= 1
		if bullets_left <= 0:
			reload_left = BURST_COOLDOWN


# ---------- 返航：回到自己的轨道 ----------
func _do_return(delta: float) -> void:
	var want := _base_orbit_point()
	_steer_towards(want, delta)
	if global_position.distance_to(want) <= ORBIT_ARRIVE_DIST:
		_state_to(State.IDLE)


# ============================================================
# 转向行为（照搬 GSAISeek / GSAIFlee）
# ============================================================

## GSAISeek：朝目标方向的满加速度
func _seek() -> Vector2:
	if current_target == null:
		return Vector2.ZERO
	return global_position.direction_to(current_target.global_position) * ACCEL_MAX


## GSAIFlee：背离目标方向的满加速度。
## ★ 加了距离加权：**贴得越近推得越狠**。
##   纯照搬 demo 的"恒定满加速度"时，无人机冲进死区后惯性还在，
##   实测会贴到离敌人 5px（几乎重叠、看着穿模）。
##   越近推力越大，就能把它及时推出来 —— 这也更符合"逃离"的直觉。
func _flee(dist: float) -> Vector2:
	if current_target == null:
		return Vector2.ZERO
	var dir := global_position.direction_to(current_target.global_position)
	# dist 越小 → 系数越大（最近时 2.5 倍，到 ENGAGE_NEAR 时回到 1 倍）
	var boost := clampf(ENGAGE_NEAR / maxf(dist, 12.0), 1.0, 2.5)
	return -dir * ACCEL_MAX * boost


## 把加速度积分成速度（照搬 agent._apply_position_steering）
##   velocity = (velocity + accel × delta).limit_length(SPEED_MAX)
##   position += velocity × delta
func _apply(accel: Vector2, delta: float) -> void:
	velocity = (velocity + accel * delta).limit_length(SPEED_MAX)
	global_position += velocity * delta


## 朝某个点飞：先按距离决定要不要减速，再把"期望速度 − 当前速度"当加速度交给 _apply。
## 用于待机绕轨道 / 返航这种"要停到位"的场合 —— 纯 seek 会冲过头。
func _steer_towards(target_pos: Vector2, delta: float) -> void:
	var to_target := target_pos - global_position
	var dist := to_target.length()
	if dist < 0.01:
		velocity = velocity.move_toward(Vector2.ZERO, ACCEL_MAX * delta)
		return
	var desired_speed := SPEED_MAX
	if dist < 110.0:
		desired_speed *= dist / 110.0
	var desired_vel := to_target / dist * desired_speed
	_apply((desired_vel - velocity).limit_length(ACCEL_MAX), delta)


## 朝向：飞行时跟速度走；攻击时朝目标（和弹道一致，避免侧身开火）
func _face_velocity(delta: float) -> void:
	var want := rotation
	if state == State.ATTACK and current_target != null and is_instance_valid(current_target):
		var to_t: Vector2 = current_target.global_position - global_position
		if to_t.length_squared() < 1.0:
			return
		want = to_t.angle()
	elif velocity.length_squared() > 4.0:
		want = velocity.angle()
	else:
		return
	rotation = rotate_toward(rotation, want, TURN_SPEED * delta)


# ============================================================
# 位置 / 开火
# ============================================================

## 本机专属轨道半径：按防御塔射程分层
func _orbit_radius() -> float:
	if home_base == null or not is_instance_valid(home_base):
		return ORBIT_FALLBACK_RADIUS
	var scope := float(home_base.radarScope)
	if scope <= 0.0:
		scope = ORBIT_FALLBACK_RADIUS
	var inner := scope * ORBIT_RADIUS_RATIO
	var step := maxf(scope * ORBIT_STEP_RATIO, ORBIT_MIN_STEP)
	return inner + step * float(slot_index)


func _base_orbit_point() -> Vector2:
	return home_base.global_position + Vector2.from_angle(_orbit_angle) * _orbit_radius()


func _fire() -> void:
	if current_target == null or not is_instance_valid(current_target):
		return
	if shotSound:
		shotSound.play()
	var b = BULLET.instantiate()
	b.global_position = global_position + Vector2.from_angle(rotation) * MUZZLE_OFFSET
	b.angle = (current_target.global_position - global_position).angle()
	b.source_tower = home_base
	b.damage = bullet_damage
	Game.addObj(b)


# ============================================================
# 尾迹
# ============================================================

func _update_trail() -> void:
	if trail == null:
		return
	var moved := global_position.distance_to(_last_trail_pos)
	if moved > TRAIL_BREAK_DISTANCE:
		trail.clear_points()
		_last_trail_pos = global_position
		trail.add_point(global_position)
		return
	if moved < TRAIL_MIN_STEP:
		return
	_last_trail_pos = global_position
	trail.add_point(global_position)
	while trail.get_point_count() > TRAIL_MAX_POINTS:
		trail.remove_point(0)
