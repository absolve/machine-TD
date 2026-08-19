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


@onready var rader = $radar
@onready var raderShape = $radar/CollisionShape2D
@onready var base = $base
@onready var turret = $turret
@onready var delayTimer = $delay
@onready var marker = $turret/Marker2D
@onready var player = $player
@onready var initBar = $ProgressBar
@onready var btnSell = $btnSell

func _ready() -> void:
	if raderShape.shape:
		raderShape.shape.radius = radarScope
	delayTimer.wait_time = delay
	monitorable = false
	set_physics_process(false)
	var tween = create_tween()
	tween.tween_property(initBar, "value", 100, 1)
	tween.tween_callback(init)
	
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
	if TowerUpgradeManager.configs[type]["exp" + str(level)] == INF:
		return
	towerExp += amount
	var threshold = TowerUpgradeManager.getExpThreshold(type, level)
	if towerExp >= threshold:
		levelUp()
		towerExp -= threshold
	
#升级等级
func levelUp() -> void:
	level += 1
	#TODO
	

func _on_delay_timeout():
	canShot = true
	

func _draw():
	if selected:
		draw_circle(Vector2.ZERO, radarScope, Color(0.1, 0.1, 0.1, 0.2))
	

func _on_input_event(_viewport, _event, _shape_idx):
	#if event is InputEventMouseButton:
		#if event.is_pressed()&& event.button_index==MouseButton.MOUSE_BUTTON_LEFT:
			#selected=!selected
			#queue_redraw()
	if Input.is_action_pressed("click"):
		hideSelect()


func _on_btn_sell_pressed():
	Game.sellTower.emit(sellingPrice)
	queue_free()
