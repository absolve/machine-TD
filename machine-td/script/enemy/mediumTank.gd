extends "res://script/enemy/enemy.gd"


var bullet: PackedScene = preload("res://scene/bullet/enemy_bullet.tscn")


func _ready() -> void:
	parent = get_parent()
	setupEnemyInfo()

#func hurt(_num: int, _source = null):
	#hp -= _num
	#lifeBar.value = hp
	#if hp < 0:
		#ExplosionManage.playExplosion(global_position)
		#Game.enemyRewarded.emit(reward)
		#owner.queue_free()

func fire(towerTarget: Node2D) -> void:
	if not is_instance_valid(towerTarget):
		return
	if canShot:
		canShot = false
		var b = bullet.instantiate()
		# 用 getMuzzlePosition()：从**炮口**发射，而不是炮塔轴心（轴心在车体中心，
		# 子弹会看起来从坦克肚子里飞出来）。
		var muzzle: Vector2 = getMuzzlePosition()
		b.global_position = muzzle
		# 瞄着目标发射，而不是顺着炮塔当时的朝向（炮塔没转到位时那会打偏）
		b.angle = (towerTarget.global_position - muzzle).angle()
		b.damage = atk
		b.target = towerTarget
		Game.addObj(b)
		# 开火音：每个敌人一种，带音高抖动，连射时不会听着像复读
		SoundManage.playAt("cannon_fire_c", turret.global_position, -6.0, randf_range(0.95, 1.05))
		# 开火后坐：这个敌人自己写 fire()，不走 attackTower()，所以要手动补一句
		playTurretRecoil()
		delayTimer.start()
	

func _physics_process(delta: float) -> void:
	if points.size() == 0:
		return
	parent.progress += speed * delta
	if parent.progress_ratio >= 1:
		Game.enemyEscaped.emit(lossPoints)
		owner.queue_free()
	var temp = pickTarget()
	if temp != null and aimAt(temp, delta):
		fire(temp)
