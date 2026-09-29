extends "res://script/bullet/bullet.gd"

var bombScene = preload("res://scene/explosion/bomb.tscn")

func _ready():
	alignToAngle()
	lifetime = 5
	vec = Vector2(300, 0).rotated(angle)
	damage = 40

func _spawnBomb() -> void:
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
	bomb.z_index = 10
	bomb.targetMask = 1 << 1 # 只命中敌人 layer 2
	Game.addObj(bomb)
	queue_free()

func _physics_process(delta):
	timer += delta
	position += vec * delta
	if timer > lifetime:
		_spawnBomb()
		return
	var temp = get_overlapping_areas()
	if temp:
		_spawnBomb()
