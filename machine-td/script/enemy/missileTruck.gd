extends "res://script/enemy/enemy.gd"
#导弹车  每隔一段时间发射导弹攻击范围的防御塔

var bulletScene = preload("res://scene/bullet/enemy_missile.tscn")


func _ready():
	parent = get_parent()
	setupEnemyInfo()


func fire(t):
	if not is_instance_valid(t):
		return
	if canShot:
		canShot = false
		var b = bulletScene.instantiate()
		# 用 get_muzzle_position()：新素材把炮塔画进了车体，缺 turret 节点时
		# 它退回车身前方，不会像直接写 turret.global_position 那样崩。
		var muzzle: Vector2 = get_muzzle_position()
		b.global_position = muzzle
		# 瞄着目标发射，而不是顺着炮塔当时的朝向（炮塔没转到位时那会打偏）
		b.angle = (t.global_position - muzzle).angle()
		b.damage = atk
		b.target = t
		Game.addObj(b)
		# 开火音：每个敌人一种，带音高抖动，连射时不会听着像复读
		SoundManage.play_at("rocket_fire_b", muzzle, -6.0, randf_range(0.95, 1.05))
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


func _on_radar_area_entered(area: Area2D) -> void:
	target.append(area)


func _on_radar_area_exited(area: Area2D) -> void:
	target.erase(area)
