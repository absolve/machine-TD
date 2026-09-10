extends "res://script/enemy.gd"
#自爆卡车 敌人

# 与目标的引爆距离（必须小于该敌人在 Game.enemyInfo 里配置的 scope，否则雷达还没锁到目标就已擦身而过）
const DETONATE_DISTANCE := 80.0

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
	# 雷达内的目标可能已被出售/摧毁，先剔除失效引用
	while not target.is_empty() and not is_instance_valid(target[0]):
		target.remove_at(0)
	if target.size() > 0:
		var temp = target[0]
		var distance = global_position.distance_to(temp.global_position)
		if distance <= DETONATE_DISTANCE:
			trigger_self_explode()

func _on_radar_area_entered(area):
	target.append(area)

func _on_radar_area_exited(area):
	target.erase(area)
