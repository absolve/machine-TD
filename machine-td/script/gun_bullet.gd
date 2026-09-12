extends "res://script/bullet.gd"


func _ready():
	lifetime = 3
	vec = Vector2(500, 0).rotated(angle)
	#damage = source_tower.atk if is_instance_valid(source_tower) else 20

func _physics_process(delta):
	timer += delta
	position += vec * delta
	if timer > lifetime:
		queue_free()
	var temp = get_overlapping_areas()
	if temp:
		for i in temp:
			if i.has_method("hurt"):
				# 带上发射者，敌人死亡时才能把经验算给这座塔
				i.hurt(damage, source_tower)
		spawn_hit_effect()
		queue_free()
