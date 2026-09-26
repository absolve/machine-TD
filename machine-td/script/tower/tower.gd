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
var invincible := false
var _invincible_left := 0.0

## 修满血的最高费用占造价的百分比（残血越多越贵，满血时为 0）
const REPAIR_COST_RATIO := 0.5

## 修理费用：按“缺失血量比例 × 造价 × REPAIR_COST_RATIO”计算，向上取整。
## 满血返回 0（无需修理）。
var repairCost: int:
	get:
		if maxHp <= 0 or hp >= maxHp:
			return 0
		var missing_ratio := float(maxHp - hp) / float(maxHp)
		return maxi(1, int(ceil(float(money) * REPAIR_COST_RATIO * missing_ratio)))

var radarSweepAngle := 0.0
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
var _baseDelay = 0

## 炮口到轴心的像素距离 —— 代码里写 `marker.position`，**不要**去场景里改 Marker2D。
##
## ⚠️ 为什么放代码里：Marker2D 在基场景 Tower.tscn 里是 (0,0)，子场景就算覆盖了，
##    只要在编辑器里一保存那个子场景，覆盖就**会被丢掉**（特斯拉那次就丢了，
##    表现是"闪电从塔中心发出来"）。写成导出变量，值跟着脚本走，谁也覆盖不掉。
##
## 取值 = 该塔炮塔贴图的炮口到贴图中心的距离（贴图轴心大多就是贴图中心）：
##   机枪 31 / 加农 47 / 火箭 61 / EMP 0 / 激光 0 / 特斯拉 0 / 无人机 0
## 注意炮塔贴图的 `AnimatedSprite2D.offset` 只是**视觉**平移，不影响子节点，
## 所以这里必须显式写，不能指望它把 Marker2D 一起带走。
@export var muzzleOffset: float = 0.0


@onready var rader = $radar
@onready var raderShape = $radar/CollisionShape2D
@onready var base = $base
@onready var turret = $turret
@onready var delayTimer = $delay
@onready var marker = $turret/Marker2D
@onready var player = $player
@onready var initBar = $ProgressBar
@onready var towerRank = $towerRank
@onready var lifeBar = $lifeBar
@onready var deploySound = $deploySound
@onready var spark = $spark
# 开火特效播放器：只有配置了炮口闪光的塔才有这个节点，其余塔为 null
@onready var sparkPlayer = get_node_or_null("sparkPlayer")


func _ready() -> void:
	if raderShape.shape:
		raderShape.shape.radius = radarScope
	if maxHp <= 0 and hp > 0:
		maxHp = hp
	if hp <= 0 and maxHp > 0:
		hp = maxHp
	delayTimer.wait_time = delay
	# 炮口位置由代码写（原因见 muzzleOffset 的注释：场景里的覆盖会被编辑器丢掉）
	if marker != null:
		marker.position = Vector2(muzzleOffset, 0.0)
	# 记下 1 级的 reload 当基准，算出当前的动画倍速。
	# ⚠️ 必须**建塔时**就抓一次 —— 升级会把 delay 改掉，之后再取就再也拿不到 1 级的值了。
	#    towerInfo 里存的就是 1 级数值，所以直接查表，不依赖"此刻的 delay 恰好是 1 级"。
	_baseDelay = delay
	refreshAniSpeed()
	monitorable = false
	set_physics_process(false)
	#set_process(false) # 只有进入无敌状态才需要逐帧倒计时
	deploySound.play()
	var tween = create_tween()
	tween.tween_property(initBar, "value", 100, initTime)
	tween.tween_callback(init)
	call_deferred("update_status_ui")

func _physics_process(delta: float) -> void:
	if not selected:
		return
	radarSweepAngle = fmod(radarSweepAngle + delta * RADAR_SCAN_SPEED, TAU)
	queue_redraw()
	if invincible: # 无敌期间
		_invincible_left -= delta
		if _invincible_left <= 0.0:
			_set_invincible_visual(false)


func getTarget():
	var temp = null
	if target.size() == 1:
		temp = target[0]
	elif target.size() > 1:
		temp = target[0]
	
	return temp

func can_target(area: Area2D) -> bool:
	if not is_instance_valid(area) or not area is Enemy:
		return false
	var can_target_air := type in [Game.towerType.droneBase, Game.towerType.laserTower, Game.towerType.rocketTower]
	return not area.flying or can_target_air

func add_target(area: Area2D) -> void:
	if not can_target(area):
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
	update_status_ui()
	Game.clickTower.emit(self, selected)

# 增加经验
func addExp(amount: int) -> void:
	if level >= TowerUpgradeManager.MAX_LEVEL:
		update_status_ui()
		return
	# 没有升级配置、或被明确排除的塔（如 EMP 干扰塔）不参与升级
	if not TowerUpgradeManager.canUpgrade(type):
		update_status_ui()
		return
	towerExp += amount
	var threshold = TowerUpgradeManager.getExpThreshold(type, level)
	if towerExp >= threshold:
		levelUp()
		towerExp -= threshold
	update_status_ui()

func update_status_ui() -> void:
	if maxHp <= 0:
		maxHp = max(hp, 1)
	if lifeBar:
		lifeBar.visible = true
		lifeBar.maxHp = maxHp
		lifeBar.value = hp
	# 修理按钮依赖血量状态刷新（右侧信息面板每帧调用 refresh）
	
#升级等级
func levelUp() -> void:
	level += 1
	var levelConfig: Dictionary = TowerUpgradeManager.getLevelConfig(type, level)
	if levelConfig.has("atk"):
		atk = levelConfig.atk
	if levelConfig.has("reload"):
		delay = levelConfig.reload
		delayTimer.wait_time = delay
		# 射速变了，开火动画倍速要跟着变（见 aniSpeed 的注释）
		refreshAniSpeed()
	if levelConfig.has("scope"):
		radarScope = levelConfig.scope
		if raderShape.shape:
			raderShape.shape.radius = radarScope
	towerRank.setLevel(level)
	playUpgradeGlow()
	update_status_ui()
	TowerUpgradeManager.tower_leveled_up.emit(self, level)
	

# 升级闪光: 启用 shader -> 亮度淡入 -> 闪烁 -> 淡出 -> 关闭
func playUpgradeGlow() -> void:
	# ⚠️ 必须判空：不是每种塔都同时有 base 和 turret 两个精灵
	#   （droneBase 就没有 turret），而且材质万一不是 ShaderMaterial
	#   时 as 的结果是 null，直接 set_shader_parameter 会报错。
	#   stopGlow() 里本来就有判空，这里之前漏了。
	var bm := base.material as ShaderMaterial
	var tm := turret.material as ShaderMaterial
	if bm:
		bm.set_shader_parameter("enable_flash", true)
	if tm:
		tm.set_shader_parameter("enable_flash", true)

	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(stopGlow)
	# tw.tween_method(setGlowIntensity, 1.0, 0.0, 0.3) # 0.3s 淡出
	# tw.tween_callback(stopGlow)


# func setGlowIntensity(value: float) -> void:
# 	(base.material as ShaderMaterial).set_shader_parameter("brightness", value)
# 	(turret.material as ShaderMaterial).set_shader_parameter("brightness", value)


func stopGlow() -> void:
	var bm := base.material as ShaderMaterial
	var tm := turret.material as ShaderMaterial
	if bm:
		bm.set_shader_parameter("enable_flash", false)
	if tm:
		tm.set_shader_parameter("enable_flash", false)


func _on_delay_timeout():
	canShot = true


## 1 级的 reload。查 game.gd 的 towerInfo（那里存的就是 1 级数值）。
## 查不到就退回"当前 delay"—— 退回的值会让 aniSpeed 恰好是 1.0，
## 也就是"不动画"，比乱算一个倍速安全。
func _lookup_base_delay() -> float:
	var info = Game.towerInfo.get(type)
	if info is Dictionary and info.has("reload"):
		var r := float(info["reload"])
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
	if delay <= 0.0:
		return
	aniSpeed = _baseDelay / delay
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
func set_invincible(duration: float) -> void:
	if duration <= 0.0:
		return
	invincible = true
	# 重复施加时取更长的剩余时间，不做叠加
	_invincible_left = maxf(_invincible_left, duration)
	_set_invincible_visual(true)
	set_process(true)


# 无敌期间用安全黄色高亮，和"我方强化"的视觉约定一致
func _set_invincible_visual(on: bool) -> void:
	if on:
		modulate = Color(1.0, 0.92, 0.55, 1.0)
		return
	invincible = false
	_invincible_left = 0.0
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	set_process(false)

func hurt(_num: int, _source = null, _damage_type: String = "physical"):
	if invincible:
		return
	if hp <= 0:
		return
	var actual_damage: float = float(_num)
	if _damage_type == "physical":
		actual_damage *= 1.0
	elif _damage_type == "energy":
		actual_damage = float(_num)
	else:
		actual_damage *= 1.0
	
	hp -= int(max(0.0, ceil(actual_damage)))
	if maxHp <= 0:
		maxHp = max(hp, 1)
	if lifeBar:
		lifeBar.maxHp = maxHp
		lifeBar.value = hp
	update_status_ui()
	if hp <= 0:
		# 塔被打爆：金属垮塌声，跟着塔的位置走
		SoundManage.play_at("tower_destroyed", global_position, -3.0, randf_range(0.95, 1.05))
		queue_free()
	

func get_muzzle_position() -> Vector2:
	if is_instance_valid(marker):
		return marker.global_position
	return global_position


# 开火特效：把炮口闪光转到目标方向，并播放一次 spark 动画
# spark 是挂在塔根节点下的（不跟着炮管转），所以这里要手动设一次朝向
# 没有配置 sparkPlayer 的塔（EMP / 特斯拉 / 激光 / 无人机基地）会自动跳过
func play_muzzle_flash(target_position: Vector2) -> void:
	if spark == null or sparkPlayer == null:
		return
	spark.rotation = (target_position - marker.global_position).angle()
	sparkPlayer.play("spark")

func _draw():
	if not selected:
		return
	var radar_color := Color(0.25, 0.75, 1.0, 1.0)
	draw_circle(Vector2.ZERO, radarScope, Color(radar_color.r, radar_color.g, radar_color.b, 0.12))
	draw_arc(Vector2.ZERO, radarScope, 0.0, TAU, 64, Color(radar_color.r, radar_color.g, radar_color.b, 0.8), 2.0)
	for i in range(1, 4):
		var r = radarScope * (i / 4.0)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(radar_color.r, radar_color.g, radar_color.b, 0.15), 1.0)
	var segments := 24
	var tail_span := PI / 3.0
	for s in range(segments):
		var t = float(s) / segments
		var a = radarSweepAngle - tail_span * t
		var alpha = (1.0 - t) * 0.5
		var next_a = radarSweepAngle - tail_span * (float(s + 1) / segments)
		var p1 = Vector2(cos(a), sin(a)) * radarScope
		var p2 = Vector2(cos(next_a), sin(next_a)) * radarScope
		draw_polygon(
			PackedVector2Array([Vector2.ZERO, p1, p2]),
			PackedColorArray([
				Color(radar_color.r, radar_color.g, radar_color.b, alpha),
				Color(radar_color.r, radar_color.g, radar_color.b, alpha),
				Color(radar_color.r, radar_color.g, radar_color.b, 0.0)
			])
		)
	draw_line(
		Vector2.ZERO,
		Vector2(cos(radarSweepAngle), sin(radarSweepAngle)) * radarScope,
		Color(radar_color.r, radar_color.g, radar_color.b, 1.0),
		2.0
	)
	

func _on_input_event(_viewport, _event, _shape_idx):
	#if event is InputEventMouseButton:
		#if event.is_pressed()&& event.button_index==MouseButton.MOUSE_BUTTON_LEFT:
			#selected=!selected
			#queue_redraw()
	if Input.is_action_just_pressed("click"):
		hideSelect()


# 出售前需要额外清理的塔（如无人机基地）覆写本方法
func _on_before_sell() -> void:
	pass


# 出售防御塔（由右侧信息面板的出售按钮调用）
func sell():
	if selected:
		hideSelect() # 出售前先取消选中，让右侧信息面板与地图状态同步清理
	_on_before_sell()
	# 出售：金币响声（先响再 free，free 之后位置就没了）
	#SoundManage.play_at("tower_sold", global_position, -2.0, randf_range(0.97, 1.05))
	SoundManage.play("tower_sold_b")
	Game.sellTower.emit(sellingPrice, coverGrid)
	queue_free()


# 请求修理：费用由 map 统一扣款，扣款成功后 map 会回调 apply_repair()
func request_repair() -> bool:
	var cost := repairCost
	if cost <= 0:
		return false
	Game.repairTower.emit(cost, self)
	return true


# 实际把血量回满（由 map 在扣除费用后调用）
func apply_repair() -> void:
	if maxHp <= 0:
		return
	hp = maxHp
	update_status_ui()
	# 回满血：能量充盈声
	# 素材已归一化过响度，不要再压（压了会像 tower_select 那次一样几乎听不见）
	SoundManage.play_at("tower_healed", global_position, 0.0)
	playRepairGlow()


# 修理完成后的闪光反馈（复用升级闪光 shader）
func playRepairGlow() -> void:
	var bm := base.material as ShaderMaterial
	var tm := turret.material as ShaderMaterial
	if bm:
		bm.set_shader_parameter("enable_flash", true)
	if tm:
		tm.set_shader_parameter("enable_flash", true)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(stopGlow)
