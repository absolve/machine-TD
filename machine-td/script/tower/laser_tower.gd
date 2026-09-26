extends "res://script/tower/tower.gd"

const MAX_TARGETS := 3 # 最多同时锁定3个目标
## 炮塔转速（弧度/秒）。
##
## 本塔的炮塔是个**径向对称的八向阵**（8 个发射头围一圈），朝向并不影响能不能打 ——
## 8 个头发射的激光在 _draw 里是从 marker 位置分别连到各自目标的。
## 所以不需要"把炮口死死对准某一个敌人"（那会让它像普通炮塔一样来回抽动），
## 改成**跟锁定数量挂钩的自转**：
##   没有目标 → TURN_IDLE 慢慢转，塔是活的、在待机扫描
##   锁定越多 → 转得越快，读起来就是"供能在爬升"
const TURN_IDLE := 0.35 # 无目标：缓慢自转
const TURN_PER_TARGET := 0.75 # 每多锁定一个目标，额外加多少转速
## 平滑系数（越大越"猛地"提速）。转速变化本身要平滑，否则锁定数一变就一顿。
const SPIN_SMOOTH := 5.0


@onready var muzzleFx: CPUParticles2D = get_node_or_null("muzzleFx")

## 命中点的**持续**喷溅火花：目标身上一直冒，不是打一下冒一下。
## 因为激光能同时锁 3 个目标，所以场景里摆了 3 组（hitFx0/1/2），一个目标一组；
## 目标少于 3 个时多出来的那组直接关掉 emitting，不浪费。
## 这里按名字前缀自动收集，以后要改同时攻击的目标数，只要在场景里增删 hitFx* 就行。
@onready var _hit_fx: Array = _collect_hit_fx()

var laser_targets: Array = [] # 当前激光锁定的敌人
## 持续攻击音的开关状态（有目标就循环响，没目标就停）
var _laser_loop_on := false
## 当前自转速度（弧度/秒）。用平滑器跟着目标数走，避免锁定数一变就"一顿"。
var _spin_speed := 0.0
## 部署动画（initTime 那 1.6 秒）放完了没有。
## 基类 _ready 里 `set_physics_process(false)`，要等 init() 才打开；
## 但这里还是再立一个自己的标志，免得依赖基类的时序。
var deployed := false


func _ready():
	#turret.rotation = randf() * TAU
	super._ready()
	#var mat =base.material as ShaderMaterial
	#mat.set_shader_parameter("enabled", 1.0)
	#var tween = create_tween()
	#tween.tween_property(mat, "shader_parameter/intensity", 1.5, 0.15)
	#tween.tween_interval(10.6)
	#tween.tween_property(mat, "shader_parameter/intensity", 0.0, 0.4)
	#tween.tween_callback(func(): mat.set_shader_parameter("enabled", 0.0))
	

## 部署完成：从这一刻起炮塔开始自转（部署那 1.6 秒它是半透明虚影，不该转）
func init() -> void:
	super.init()
	deployed = true

func _physics_process(_delta: float):
	super._physics_process(_delta)
	# 收集最多3个有效目标
	laser_targets = _collect_targets()

	# 命中点的持续喷溅火花：跟着目标跑（和激光末端同一个坐标）
	_update_hit_fx()

	# 炮塔自转：转速跟着锁定数量走（没有目标也慢慢转，塔是活的）。
	# ⚠️ 必须等 init() 之后才转 —— 建塔动画那 1.6 秒里 base/turret 还是半透明的虚影，
	#    让它转起来看着像 bug。
	if deployed:
		var want_speed := TURN_IDLE + TURN_PER_TARGET * float(laser_targets.size())
		_spin_speed = lerpf(_spin_speed, want_speed, SPIN_SMOOTH * _delta)
		turret.rotation += _spin_speed * _delta

	# 伤害扣血: 使用 delayTimer/canShot 间隔扣血(与其他塔一致的脉冲机制)
	if not laser_targets.is_empty() and canShot:
		fire_lasers()
		canShot = false
		delayTimer.start()

	# 持续攻击音：有目标就一直循环响，目标没了就停。
	# 用 SoundManage 的循环通道（start_loop/stop_loop），它内部自己管播放器，
	# 所以不用在这个场景里塞 AudioStreamPlayer，也不怕塔被卖掉时声音残留。
	var want_loop := not laser_targets.is_empty()
	if want_loop != _laser_loop_on:
		_laser_loop_on = want_loop
		if want_loop:
			SoundManage.start_loop("laser_tower", "tower_laser_charge", -14.0)
		else:
			SoundManage.stop_loop("laser_tower")

	# 只要有目标就持续重绘(激光视觉一直存在,不与扣血频率绑定)
	# 注意: 目标消失时也必须 queue_redraw, 否则 _draw 不会被调用来清空画布, 会留下激光残影
	queue_redraw()


# 对所有锁定目标同时扣血一次(每次 atk 点伤害)，并在炮口播放开火粒子
func fire_lasers():
	_play_muzzle_fx(get_muzzle_position())
	for enemy in laser_targets:
		if is_instance_valid(enemy) and enemy.has_method("hurt"):
			enemy.hurt(atk,self)
			# 命中视觉交给场景里那几组 hitFx*（持续喷溅火花，见 _update_hit_fx）。
			# 这里**故意不叫** ExplosionManage.playHit —— 那是通用的一次性爆闪，
			# 激光每来一发脉冲就砸上去一颗，会把持续火花整个盖成一团火球，
			# 连敌人本身都糊住看不见了。激光的命中反馈就只留"一直在溅的火花"。
			# 命中音：每个被打到的敌人身上响一声。音高抖动大一些（±15%），
			# 因为激光是持续多目标攻击，固定音高连成一片会像警报。
			SoundManage.play_at("hit_hard", enemy.global_position, -11.0, randf_range(0.85, 1.20))


# 炮口粒子：粒子就在**本场景里**（muzzleFx），直接挪到炮口重播即可。
# 不再 instantiate 单独的场景 —— 一秒钟要放好几次，反复新建销毁很浪费；
# 而且粒子是塔的一部分，塔被卖掉时会跟着一起销毁，不会残留。
func _play_muzzle_fx(pos: Vector2) -> void:
	if muzzleFx == null:
		return
	muzzleFx.global_position = pos
	muzzleFx.restart()
	muzzleFx.emitting = true


# 收集最多MAX_TARGETS个有效目标
func _collect_targets() -> Array:
	var result: Array = []
	for t in target:
		if is_instance_valid(t):
			result.append(t)
			if result.size() >= MAX_TARGETS:
				break
	return result


# 把场景里所有叫 hitFx* 的粒子收进来（按场景顺序 = hitFx0, hitFx1, hitFx2 ...）
func _collect_hit_fx() -> Array:
	var out: Array = []
	for c in get_children():
		if c is CPUParticles2D and String(c.name).begins_with("hitFx"):
			out.append(c)
	return out


# 每个目标配一组喷溅粒子：
#   有目标 -> 先把节点挪到目标身上，再打开 emitting；
#   没目标 -> 关掉 emitting（已经飞出去的粒子会自己飘完，不会硬切，所以不会"啪"一下消失）。
#
# ⚠️ 顺序不能反：emitting 开着的时候挪位置，新粒子会从**旧位置**冒出来（会看到一串断点）。
#
# 粒子用 local_coords = false —— 发射出去的粒子留在世界坐标里不跟着发射器走，
# 目标一边走一边被烧，火花就会在后面拖出一条喷溅的尾巴，比"黏在身上"好看。
func _update_hit_fx() -> void:
	for i in _hit_fx.size():
		var fx: CPUParticles2D = _hit_fx[i]
		if fx == null:
			continue
		var t = laser_targets[i] if i < laser_targets.size() else null
		if t != null and is_instance_valid(t):
			fx.global_position = t.global_position
			if not fx.emitting:
				fx.emitting = true
		elif fx.emitting:
			fx.emitting = false


func _draw():
	super._draw()
	if laser_targets.is_empty():
		return
	var start = to_local(marker.global_position)
	for enemy in laser_targets:
		if not is_instance_valid(enemy):
			continue
		var end = to_local(enemy.global_position)
		_draw_laser_beam(start, end)


func _draw_laser_beam(start: Vector2, end: Vector2) -> void:
	var direction = end - start
	if direction.length_squared() <= 0.0001:
		return
	var brightness := randf_range(0.55, 1.0)
	var laser_color := Color(brightness, brightness * 0.08, brightness * 0.08, 1.0)
	draw_line(start, end, laser_color, 2.0, true)


# 绘制电流抖动电弧: 沿直线分段, 每段随机垂直偏移
#func _draw_electric_arc(start: Vector2, end: Vector2, color: Color, width: float, segments: int = 8, jitter: float = 8.0):
	#var direction = end - start
	#var perp = Vector2(-direction.y, direction.x).normalized()
	#var prev = start
	#for i in range(1, segments):
		#var t = float(i) / float(segments)
		#var point = start + direction * t
		## 端点不偏移, 中间点随机垂直抖动
		#point += perp * randf_range(-jitter, jitter)
		#draw_line(prev, point, color, width)
		#prev = point
	#draw_line(prev, end, color, width)


## 塔被卖掉或摧毁时一定要停掉循环音，否则会一直响下去
func _exit_tree() -> void:
	SoundManage.stop_loop("laser_tower")


func _on_radar_area_entered(area: Area2D) -> void:
	target.push_back(area)


func _on_radar_area_exited(area: Area2D) -> void:
	target.erase(area)
