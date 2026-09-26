extends "res://script/enemy/enemy.gd"


var bullet = preload("res://scene/bullet/enemy_bullet.tscn")


func _ready() -> void:
	parent = get_parent()
	setupEnemyInfo()

#func hurt(_num: int, _source = null):
	#hp -= _num
	#lifeBar.value = hp
	#if hp < 0:
		#ExplosionManage.playExplosion(global_position)
		#Game.defeatEnemy.emit(reward)
		#owner.queue_free()

func fire(t):
	if not is_instance_valid(t):
		return
	if canShot:
		canShot = false
		var b = bullet.instantiate()
		b.global_position = turret.global_position
		# 瞄着目标发射，而不是顺着炮塔当时的朝向（炮塔没转到位时那会打偏）
		b.angle = (t.global_position - turret.global_position).angle()
		b.damage = atk
		b.target = t
		Game.addObj(b)
		# 开火音：每个敌人一种，带音高抖动，连射时不会听着像复读
		SoundManage.play_at("cannon_fire_c", turret.global_position, -6.0, randf_range(0.95, 1.05))
		delayTimer.start()
	

func _physics_process(_delta):
	if points.size() == 0:
		return
	parent.progress += speed * _delta
	if parent.progress_ratio >= 1:
		Game.enemyEscape.emit(lossPoints)
		owner.queue_free()
	var temp = pick_target()
	if temp != null and aim_at(temp, _delta):
		fire(temp)

func _on_radar_area_entered(area):
	target.append(area)

func _on_radar_area_exited(area):
	target.erase(area)
