extends "res://script/bullet/bullet.gd"
## 火箭弹：出膛后靠自身的小雷达锁定附近**同类**敌人，并逐渐转向追上去。
##
## 为什么需要雷达：本弹基础速度只有 [member bulletSpeed]（300 像素/秒），
## 直射时目标只要稍一移动 / 换向就会擦身而过，然后一直飞到 5 秒寿命才自炸 ——
## 表现就是"火箭塔打不中人"。
## 现在子弹自带一个圆形雷达（场景里的 Radar 子节点，见 rocketbullet.tscn）：
##   ① 每物理帧取"雷达圈内、仍有效、且与出膛时同属地面 / 空中"的最近敌人；
##   ② 用有限的角速度 [member turnSpeed] 把飞行方向**逐渐**转过去（不是瞬间锁定）。
## 有目标就拐弯咬住，没有就保持直线；命中判定与爆炸逻辑完全不变。

## 转向角速度（弧度 / 秒）。越大拐弯越急：300 像素/秒 ÷ 5 弧度/秒 ≈ 60 像素转弯半径。
@export var turnSpeed: float = 5.0

## 飞行速度（像素 / 秒）。原来是写死在 `_ready()` 里的 300，提到导出方便调手感。
@export var bulletSpeed: float = 300.0

var bombScene: PackedScene = preload("res://scene/explosion/bomb.tscn")
var targetFlying: bool = false

## 雷达圈内的候选敌人，由 Radar 的 area_entered / area_exited 维护
var nearbyEnemies: Array[Area2D] = []


func _ready() -> void:
	alignToAngle()
	lifetime = 5.0
	vec = Vector2(bulletSpeed, 0).rotated(angle)


## 雷达进 / 出：只收敌人。Radar 的 mask 已限定 layer 2（敌人），这里再兜一层类型判断。
func onRadarAreaEntered(area: Area2D) -> void:
	if area is Enemy and not nearbyEnemies.has(area):
		nearbyEnemies.append(area)


func onRadarAreaExited(area: Area2D) -> void:
	nearbyEnemies.erase(area)


## 取雷达圈内"最近的、仍有效的、与本弹同类"的敌人；顺手清掉失效条目。
##
## "同类"（地面 / 空中）这一条必须和爆炸的过滤规则一致：bomb 用
## `filterFlyingTargets` + `targetFlying` 只伤同类，
## 这里若去追异类目标，就会咬住一个"炸了也不掉血"的敌人白费寿命。
func pickHomingTarget() -> Enemy:
	var best: Enemy = null
	var bestDistanceSquared: float = INF
	var alive: Array[Area2D] = []
	for area in nearbyEnemies:
		if not is_instance_valid(area) or not area is Enemy:
			continue
		alive.append(area)
		var enemy: Enemy = area as Enemy
		if enemy.flying != targetFlying:
			continue
		var distanceSquared: float = global_position.distance_squared_to(enemy.global_position)
		if distanceSquared < bestDistanceSquared:
			bestDistanceSquared = distanceSquared
			best = enemy
	nearbyEnemies = alive
	return best


## 把飞行方向朝目标**逐渐**转过去（每帧最多转 turnSpeed * delta），并同步贴图朝向
func steerToward(enemy: Enemy, delta: float) -> void:
	var wantAngle: float = (enemy.global_position - global_position).angle()
	var difference: float = wrapf(wantAngle - angle, -PI, PI)
	angle = angle + clampf(difference, -turnSpeed * delta, turnSpeed * delta)
	rotation = angle
	vec = Vector2(bulletSpeed, 0).rotated(angle)


func spawnBomb() -> void:
	if is_queued_for_deletion():
		return
	spawnHitEffect()
	# 爆炸的**视觉**（动画 + 粒子 + 音效）走新的统一入口；
	# bomb 只负责范围伤害，它自带的旧爆炸动画会被隐藏（见 bomb.gd）。
	ExplosionManage.playExplosion(global_position)
	var bomb = bombScene.instantiate()
	bomb.global_position = global_position
	bomb.damage = sourceTower.atk if is_instance_valid(sourceTower) else damage
	if is_instance_valid(sourceTower):
		bomb.sourceTower = sourceTower
		bomb.source = sourceTower
	bomb.blastRadius = 90.0
	bomb.filterFlyingTargets = true
	bomb.targetFlying = targetFlying
	bomb.z_index = 10
	bomb.targetMask = 1 << 1 # 只命中敌人 layer 2
	Game.addObj(bomb)
	queue_free()

func _physics_process(delta: float) -> void:
	timer += delta
	if timer > lifetime:
		spawnBomb()
		return
	# 有雷达目标就先拐弯，再按（可能已更新的）方向前进
	var homingTarget: Enemy = pickHomingTarget()
	if homingTarget != null:
		steerToward(homingTarget, delta)
	position += vec * delta
	for area in get_overlapping_areas():
		if area is Enemy and area.flying != targetFlying:
			continue
		if area.has_method("hurt"):
			spawnBomb()
			return
