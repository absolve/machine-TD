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
var initTime = 1 #初始化时间 秒

@onready var rader = $radar
@onready var raderShape = $radar/CollisionShape2D
@onready var base = $base
@onready var turret = $turret
@onready var delayTimer = $delay
@onready var marker = $turret/Marker2D
@onready var player = $player
@onready var initBar = $ProgressBar
@onready var btnSell = $btnSell
@onready var towerRank = $towerRank
@onready var lifeBar=$lifeBar

var radarSweepAngle := 0.0
const RADAR_SCAN_SPEED := 1.8

func _ready() -> void:
	if raderShape.shape:
		raderShape.shape.radius = radarScope
	delayTimer.wait_time = delay
	monitorable = false
	set_physics_process(false)
	var tween = create_tween()
	tween.tween_property(initBar, "value", 100, initTime)
	tween.tween_callback(init)

func _physics_process(delta: float) -> void:
	if not selected:
		return
	radarSweepAngle = fmod(radarSweepAngle + delta * RADAR_SCAN_SPEED, TAU)
	queue_redraw()
	
func getTarget():
	var temp = null
	if target.size() == 1:
		temp = target[0]
	elif target.size() > 1:
		temp = target[0]
	
	return temp

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
	btnSell.visible = selected
	Game.clickTower.emit(self, selected)

# 增加经验
func addExp(amount: int) -> void:
	if level >= TowerUpgradeManager.MAX_LEVEL:
		return
	if !TowerUpgradeManager.configs.has(type):
		return
	print('addExp', amount)
	towerExp += amount
	var threshold = TowerUpgradeManager.getExpThreshold(type, level)
	if towerExp >= threshold:
		levelUp()
		towerExp -= threshold
	
#升级等级
func levelUp() -> void:
	level += 1
	var levelConfig: Dictionary = TowerUpgradeManager.getLevelConfig(type, level)
	if levelConfig.has("atk"):
		atk = levelConfig.atk
	if levelConfig.has("reload"):
		delay = levelConfig.reload
		delayTimer.wait_time = delay
	if levelConfig.has("scope"):
		radarScope = levelConfig.scope
		if raderShape.shape:
			raderShape.shape.radius = radarScope
	towerRank.setLevel(level)
	playUpgradeGlow()
	

# 升级闪光: 启用 shader -> 亮度淡入 -> 闪烁 -> 淡出 -> 关闭
func playUpgradeGlow() -> void:
	var bm := base.material as ShaderMaterial
	var tm := turret.material as ShaderMaterial
	# 打开发光, intensity 从 0 开始淡入
	
	bm.set_shader_parameter("enable_flash", true)
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
	(base.material as ShaderMaterial).set_shader_parameter("enable_flash", false)
	(turret.material as ShaderMaterial).set_shader_parameter("enable_flash", false)


func _on_delay_timeout():
	canShot = true

func hurt(_num: int, _source = null, _damage_type: String = "physical"):
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
	if lifeBar:
		lifeBar.value = hp
	if hp <= 0:
		queue_free()
	

func get_muzzle_position() -> Vector2:
	if is_instance_valid(marker):
		return marker.global_position
	return global_position

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


func _on_btn_sell_pressed():
	Game.sellTower.emit(sellingPrice, coverGrid)
	queue_free()
