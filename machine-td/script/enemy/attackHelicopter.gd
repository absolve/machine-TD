extends "res://script/enemy/enemy.gd"

#攻击直升机 敌人

var bullet = preload("res://scene/bullet/enemy_bullet.tscn")


func _ready() -> void:
	parent = get_parent()
	setupEnemyInfo()


func fire(t):
	if not is_instance_valid(t):
		return
	if canShot:
		canShot = false
		var b = bullet.instantiate()
		# 用 get_muzzle_position()：本场景**没有 turret 节点**，
		# 直接写 turret.global_position 一开火就崩。没有炮塔时它退回机身前方。
		var muzzle: Vector2 = get_muzzle_position()
		b.global_position = muzzle
		# 瞄着目标发射，而不是顺着炮塔当时的朝向（炮塔没转到位时那会打偏）
		b.angle = (t.global_position - muzzle).angle()
		b.damage = atk
		b.target = t
		Game.addObj(b)
		# 开火音：每个敌人一种，带音高抖动，连射时不会听着像复读
		SoundManage.play_at("mg_fire_b", muzzle, -8.0, randf_range(0.94, 1.08))
		delayTimer.start()


func _physics_process(_delta):
	if points.size() == 0:
		return
	parent.progress += speed * _delta
	if parent.progress_ratio >= 1:
		Game.enemyEscape.emit(lossPoints)
		owner.queue_free()
	# 取最近的**有效**目标，并把炮塔转过去；到位了才开火。
	# 原来这里既不看最近、也不转炮塔，子弹顺着炮塔当时的朝向飞 —— 就是"胡乱攻击"。
	var temp = pick_target()
	if temp != null and aim_at(temp, _delta):
		fire(temp)


func _on_radar_area_entered(area):
	target.append(area)


func _on_radar_area_exited(area):
	target.erase(area)
