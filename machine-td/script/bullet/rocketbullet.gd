extends "res://script/bullet/bullet.gd"
## 火箭弹：出膛后从初速加速，并靠自身小雷达锁定附近**同类**敌人追踪。
##
## 为什么需要雷达：目标会移动或转向，导弹需要转向追踪并在飞行中逐渐加速。
## 直射时目标只要稍一移动 / 换向就会擦身而过，然后一直飞到 5 秒寿命才自炸 ——
## 表现就是"火箭塔打不中人"。
## 现在子弹自带一个圆形雷达（场景里的 Radar 子节点，见 rocketbullet.tscn）：
##   ① 每物理帧取"雷达圈内、仍有效、且与出膛时同属地面 / 空中"的最近敌人；
##   ② 用有限的角速度 [member turnSpeed] 把飞行方向**逐渐**转过去（不是瞬间锁定）。
## 有目标就拐弯咬住；持续一段时间没有雷达目标就自行销毁，不留下空爆。

## 导弹模式（火箭塔的 toggle 技能）：**没有爆炸范围**，命中时直接对单个敌人结算伤害。
## 由发射方 `rocket_tower.gd` 在实例化后设置。
@export var noSplash: bool = false
## 转向角速度（弧度 / 秒）。
@export var turnSpeed: float = 5.0
## 最大飞行速度（像素 / 秒）。
@export var bulletSpeed: float = 390.0
## 出膛初速（像素 / 秒）。
@export var initialSpeed: float = 150.0
## 加速度（像素 / 秒²）。
@export var acceleration: float = 420.0
## 雷达连续没有找到有效目标多久后自毁（秒）。
@export var noTargetTimeout: float = 1.5

var bombScene: PackedScene = preload("res://scene/explosion/bomb.tscn")
var targetFlying: bool = false
var currentSpeed: float = 0.0
var noTargetElapsed: float = 0.0

## 雷达圈内的候选敌人，由 Radar 的 area_entered / area_exited 维护
var nearbyEnemies: Array[Area2D] = []


func _ready() -> void:
	alignToAngle()
	lifetime = 5.0
	currentSpeed = minf(initialSpeed, bulletSpeed)
	vec = Vector2(currentSpeed, 0).rotated(angle)


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
	vec = Vector2(currentSpeed, 0).rotated(angle)


## `hitEnemy`：本次命中的敌人（寿命耗尽时没有目标，传 null）。
##
## ⚠️ 导弹模式的"不溅射"**不能靠把 blastRadius 调小**实现：`bomb.tscn` 的伤害本来
##    就是拿范围结算出来的，半径调到 0 只会变成一个打不到人的空爆。
##    所以这里走一条完全独立的路径：直接 `hurt()` 单个目标，**不生成 bomb 场景**。
func spawnBomb(hitEnemy: Node = null) -> void:
	if is_queued_for_deletion():
		return
	spawnHitEffect()
	if noSplash:
		# 单体直击：有目标才结算；打空了就只留命中特效（不放空爆）
		if is_instance_valid(hitEnemy) and hitEnemy.has_method("hurt"):
			hitEnemy.hurt(damage, sourceTower)
		queue_free()
		return
	# 爆炸的视觉由 bomb **自己的动画**负责（sprite/explosionSmoke1..5.png，见 bomb.gd），
	# 所以这里**不要再调 ExplosionManage.playExplosion()** —— 会叠成两套爆炸。
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

## 雷达一直没找到目标 -> 导弹自行销毁。**销毁时留一个小爆炸**，
## 否则子弹会"凭空消失"，玩家看着像掉帧/漏判。
## 用 explosion_small 变体：这是"打空了"，不该和命中敌人那样放一发大的。
## 注意这里只走 ExplosionManage 的视觉 + 音效，**不生成 bomb 场景**，
## 所以不会误伤任何东西（单体导弹模式也一样安全）。
func spawnFizzleExplosion() -> void:
	if is_queued_for_deletion():
		return
	ExplosionManage.playExplosion(global_position, "res://scene/explosion/explosion_small.tscn")
	queue_free()


func _physics_process(delta: float) -> void:
	timer += delta
	if timer > lifetime:
		spawnBomb()
		return
	currentSpeed = minf(bulletSpeed, currentSpeed + acceleration * delta)
	# 有有效雷达目标就先拐弯；一直没有目标则自毁，避免空飞到寿命结束后空爆。
	var homingTarget: Enemy = pickHomingTarget()
	if homingTarget != null:
		noTargetElapsed = 0.0
		steerToward(homingTarget, delta)
	else:
		noTargetElapsed += delta
		if noTargetElapsed >= noTargetTimeout:
			spawnFizzleExplosion()
			return
	vec = Vector2(currentSpeed, 0).rotated(angle)
	position += vec * delta
	for area in get_overlapping_areas():
		if area is Enemy and area.flying != targetFlying:
			continue
		if area.has_method("hurt"):
			spawnBomb(area)
			return
