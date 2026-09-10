extends Area2D

class_name Enemy

@export var hp = 100 # 血量
@export var speed: int # 移动速度
@export var reward = 0 # 奖励
@export var lossPoints = 1 # 损失点数
@export var rewardExp = 2 # 经验值
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

@onready var base = $base
@onready var turret = $turret
@onready var lifeBar = $lifeBar
@onready var delayTimer = $delay
@onready var radar = $radar
@onready var radarShape = $radar/shape

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
	armor = float(info.get("armor", armor))
	flying = bool(info.get("flying", flying))
	atk = int(info.get("atk", atk))
	shootDelay = float(info.get("shootDelay", shootDelay))
	radarScope = float(info.get("scope", radarScope))
	if shootDelay > 0:
		delayTimer.wait_time = shootDelay
	if lifeBar:
		lifeBar.maxHp = hp
		lifeBar.value = hp
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
	var circle := radarShape.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		radarShape.shape = circle
	circle.radius = radarScope
	radar.monitoring = true


# 点击敌人：通知地图选中它
# 这里主动把事件标记为已处理，阻止它继续传导到 map._unhandled_input 的“点空地取消选中”，
# 否则刚弹出的敌人信息面板会被同一击立刻收起来
func _on_input_event(_viewport, _event, _shape_idx):
	if _event.is_action_pressed("click"):
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()
		Game.clickEnemy.emit(self)

#受到伤害
# 物理伤害会按 armor 进行减免：实际伤害 = 原伤害 * (1 - armor)
# armor 取值范围 0~1，1 表示 100% 减免，0 表示不减伤
# 能量伤害忽略 armor
func hurt(_num: int, _source = null, _damage_type: String = "physical"):
	var actual_damage: float = float(_num)
	if _damage_type == "physical":
		actual_damage *= max(0.0, 1.0 - armor)
	elif _damage_type == "energy":
		actual_damage = float(_num)
	else:
		actual_damage *= max(0.0, 1.0 - armor)

	hp -= int(max(0.0, ceil(actual_damage)))
	if lifeBar:
		lifeBar.visible = true
		lifeBar.value = hp
	if hp <= 0:
		ExplosionManage.playExplosion(global_position)
		Game.defeatEnemy.emit(reward)
		owner.queue_free()
		if _source != null && _source is Tower:
			_source.addExp(rewardExp)

#增加血量  TODO: 有个回复血量的特效
func addHp(_num: int):
	hp += _num
	if hp > maxHp:
		hp = maxHp
	lifeBar.value = hp

func fire(_t):
	pass


func _physics_process(_delta):
	if points.size() == 0:
		return
	parent.progress += speed * _delta
	if parent.progress_ratio >= 1:
		Game.enemyEscape.emit(lossPoints)
		owner.queue_free()
