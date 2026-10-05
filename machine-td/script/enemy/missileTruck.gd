extends "res://script/enemy/enemy.gd"
## 导弹车：每隔一段时间发射导弹攻击范围内的防御塔。

var bulletScene: PackedScene = preload("res://scene/bullet/enemy_missile.tscn")


func _ready() -> void:
	parent = get_parent()
	setupEnemyInfo()


func fire(towerTarget: Node2D) -> void:
	if not is_instance_valid(towerTarget):
		return
	if canShot:
		canShot = false
		var b = bulletScene.instantiate()
		# 用 getMuzzlePosition()：导弹车新素材没有独立炮塔画在发射管处，炮口由
		# muzzleOffset 标在车头，不会像直接写 turret.global_position 那样崩。
		var muzzle: Vector2 = getMuzzlePosition()
		b.global_position = muzzle
		# 瞄着目标发射，而不是顺着炮塔当时的朝向（炮塔没转到位时那会打偏）
		b.angle = (towerTarget.global_position - muzzle).angle()
		b.damage = atk
		b.target = towerTarget
		Game.addObj(b)
		# 开火音：每个敌人一种，带音高抖动，连射时不会听着像复读
		SoundManage.playAt("rocket_fire_b", muzzle, -6.0, randf_range(0.95, 1.05))
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
