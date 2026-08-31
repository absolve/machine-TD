extends "res://script/enemy.gd"
#自爆卡车 敌人

var bombScene = preload("res://scene/bomb.tscn")

func _ready():
	parent = get_parent()
	setupEnemyInfo()

func trigger_self_explode() -> void:
	if dead:
		return
	dead = true
	var bomb = bombScene.instantiate()
	bomb.global_position = global_position
	bomb.damage = atk if atk > 0 else hp
	bomb.blastRadius = 120.0
	bomb.source = self
	bomb.source_tower = null
	bomb.damage_type = "physical"
	bomb.target_mask = 1 << 0 # 只命中塔 layer 1
	Game.addObj(bomb)
	if is_instance_valid(owner):
		owner.queue_free()
	else:
		queue_free()

func _physics_process(_delta):
	if points.size() == 0:
		return
	parent.progress += speed * _delta
	if parent.progress_ratio >= 1:
		trigger_self_explode()
		return
	if target.size() > 0:
		var temp = target[0]
		var distance = global_position.distance_to(temp.global_position)
		if distance <= 80:
			trigger_self_explode()
