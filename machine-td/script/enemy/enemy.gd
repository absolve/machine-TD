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
## ⚠️ 必须用 get_node_or_null：直升机/无人机这类**没有 turret 节点**，
##    而 `$turret` 取不到节点时会直接报错（不是返回 null）。
##    更早的坑：attackHelicopter.gd 里无条件访问 turret.global_position，
##    它一开火就会崩 —— 现在统一走 get_muzzle_position()，没有炮塔就退回机身前方。
@onready var turret = get_node_or_null("turret")
@onready var lifeBar = $lifeBar
@onready var delayTimer = $delay
@onready var radar = $radar
@onready var radarShape = $radar/shape

## 没有炮塔的敌人（直升机/无人机）：枪口/挂架相对机身中心往前多少像素。
## 车体类的炮塔自带炮管，所以这条只给"无炮塔"的用。
@export var muzzleOffset: float = 0.0


## 开火点：有**可见**炮塔就用炮塔位置，否则取机身前方 muzzleOffset 处。
## 两条路径都返回 Vector2，调用方不用再判空。
##
## ⚠️ 判断条件是 `turret.visible`，不是 `turret != null`：
##    基场景 scene/enemy/enemy.tscn **自带 turret 节点**，派生场景里删不掉它
##    （删了会退回继承基场景的那个），所以"这个敌人没有炮塔"是靠
##    `visible = false` 表达的。只看 null 会把隐藏的炮塔位置当成枪口。
func get_muzzle_position() -> Vector2:
	if turret != null and is_instance_valid(turret) and turret.visible:
		return turret.global_position
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
## 取"最近的、仍然有效的"目标；顺手把失效条目清掉。
##
## ⚠️ 三个会开火的敌人（中型坦克 / 导弹车 / 攻击直升机）原来都是直接取 target[0]。
##    那是雷达 area_entered 的**插入顺序**，不是最近的 —— 看着就像"乱打"。
##    而且失效的条目不会被清掉，会一直占着第 0 位，导致后面明明有目标却不开火。
func pick_target():
	var best = null
	var best_d := INF
	var alive: Array = []
	for t in target:
		if not is_instance_valid(t):
			continue
		alive.append(t)
		var d: float = global_position.distance_squared_to(t.global_position)
		if d < best_d:
			best_d = d
			best = t
	target = alive
	return best


## 把炮塔转向目标，返回"是否已经瞄准到位"。
## 到位才开火 —— 否则子弹会顺着炮塔当时的朝向飞出去，看着就是乱射。
func aim_at(t, delta: float) -> bool:
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
	var actual_damage: float = float(_num)
	if _damage_type == "physical":
		actual_damage *= max(0.0, 1.0 - armor)
	elif _damage_type == "energy":
		actual_damage = float(_num)
	else:
		actual_damage *= max(0.0, 1.0 - armor)

	hp -= int(max(0.0, ceil(actual_damage)))
	# 被击中亮一下（所有敌人通用，材质在基场景上）
	play_hit_flash()
	if lifeBar:
		lifeBar.visible = true
		lifeBar.value = hp
	if hp <= 0:
		ExplosionManage.playExplosion(global_position)
		Game.defeatEnemy.emit(reward)
		# 成就统计需要知道敌人类型和击杀来源，必须在节点释放之前发出
		Game.enemyDefeated.emit(self, _source)
		owner.queue_free()
		if _source != null && _source is Tower:
			_source.addExp(rewardExp)

## ── 被击中的"变亮"反馈 ──
## 材质挂在 scene/enemy/enemy.tscn 的 base / turret 上，所有敌人共用（派生场景继承得到）。
## 这里只负责把 shader 的 flash 参数从 1 补间到 0。
const HIT_FLASH_TIME := 0.10

var _hit_flash_tween: Tween


func play_hit_flash() -> void:
	_set_hit_flash(1.0)
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_method(_set_hit_flash, 1.0, 0.0, HIT_FLASH_TIME)


func _set_hit_flash(v: float) -> void:
	# base / turret 都可能不存在（无人机之类只有 base），逐个判空
	for n in [base, turret]:
		if n == null:
			continue
		var m := n.material as ShaderMaterial
		if m != null:
			m.set_shader_parameter("flash", v)

#增加血量  TODO: 有个回复血量的特效
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
func _on_delay_timeout() -> void:
	canShot = true


func _physics_process(_delta):
	if points.size() == 0:
		return
	parent.progress += speed * _delta
	if parent.progress_ratio >= 1:
		Game.enemyEscape.emit(lossPoints)
		owner.queue_free()
