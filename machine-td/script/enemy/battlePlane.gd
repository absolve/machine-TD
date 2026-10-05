extends "res://script/enemy/enemy.gd"
## 战斗飞机：**飞越地图**的空中对抗型敌人。
##
## 与其它敌人有三点不同：
##   ① 走**自己的一条独立路线** —— 关卡里单独摆的第二个 Path2D（路线2，通常横跨全图）。
##      它不沿传送带走，纯粹是"从画面这头飞到那头"的骚扰兼表演；
##   ② `lossPoints = 0`：飞到终点直接离场，**不扣基地血**。所以这里**覆写了
##      `_physics_process()`** 而不是沿用基类 —— 基类到终点会发 `Game.enemyEscaped`，
##      那会让 map 播一声"漏怪"提示锣，对一架本来就不扣血的观光飞机是误导。
##   ③ 空中单位（`flying = true`）：只有无人机基地 / 激光塔 / 火箭塔打得到它。
##
## 行为：沿路线飞行，雷达锁定射程内的防御塔，炮塔转到位就开火。
## **开火挂的是导弹**（`scene/bullet/enemy_missile.tscn`，会追踪目标），
## 不是早期那种直飞的机炮子弹 —— 飞机是“空中搞扰”，打不准就没威胁感。
## 数值（hp / atk / scope / 掉落）全部来自 `Game.enemyInfo.battlePlane`。

var bullet: PackedScene = preload("res://scene/bullet/enemy_missile.tscn")


func _ready() -> void:
	parent = get_parent()
	setupEnemyInfo()


func fire(towerTarget: Node2D) -> void:
	if not is_instance_valid(towerTarget):
		return
	if canShot:
		canShot = false
		var b = bullet.instantiate()
		# 本场景没有可见炮塔（turret 隐藏），getMuzzlePosition() 会退回机身前方
		var muzzle: Vector2 = getMuzzlePosition()
		b.global_position = muzzle
		b.angle = (towerTarget.global_position - muzzle).angle()
		b.damage = atk
		b.target = towerTarget
		Game.addObj(b)
		SoundManage.playAt("rocket_fire_b", muzzle, -8.0, randf_range(0.96, 1.10))
		delayTimer.start()


func _physics_process(delta: float) -> void:
	if points.size() == 0:
		return
	parent.progress += speed * delta
	if parent.progress_ratio >= 1:
		# 飞越结束：静静离场，**不发 enemyEscaped**（详见类文档 ②）
		owner.queue_free()
		return
	# 取最近的**有效**目标，把炮塔转过去；到位了才开火
	var temp = pickTarget()
	if temp != null and aimAt(temp, delta):
		fire(temp)
