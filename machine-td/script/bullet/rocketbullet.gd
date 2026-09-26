extends "res://script/bullet/bullet.gd"

var bomb_scene = preload("res://scene/explosion/bomb.tscn")

func _ready():
	lifetime = 5
	vec = Vector2(300, 0).rotated(angle)
	damage = 40
	rotate(angle)

func _spawn_bomb() -> void:
	if is_queued_for_deletion():
		return
	spawn_hit_effect()
	# 爆炸的**视觉**（动画 + 粒子 + 音效）走新的统一入口；
	# bomb 只负责范围伤害，它自带的旧爆炸动画会被隐藏（见 bomb.gd）。
	ExplosionManage.playExplosion(global_position)
	var bomb = bomb_scene.instantiate()
	bomb.global_position = global_position
	bomb.damage = source_tower.atk if is_instance_valid(source_tower) else damage
	bomb.source_tower = source_tower
	bomb.source = source_tower
	bomb.blastRadius = 90.0
	bomb.z_index = 10
	bomb.target_mask = 1 << 1 # 只命中敌人 layer 2
	Game.addObj(bomb)
	queue_free()

func _physics_process(delta):
	timer += delta
	position += vec * delta
	if timer > lifetime:
		_spawn_bomb()
		return
	var temp = get_overlapping_areas()
	if temp:
		_spawn_bomb()
