extends "res://script/enemy.gd"
#维修车 敌人


func _ready():
	parent = get_parent()
	setupEnemyInfo()


func fire(t):
	if canShot:
		for i in t:
			if is_instance_valid(i):
				i.addHp(atk)

func _physics_process(_delta):
	if points.size() == 0:
		return
	parent.progress += speed * _delta
	if parent.progress_ratio >= 1:
		Game.enemyEscape.emit(lossPoints)
		owner.queue_free()
	if target.size() > 0:
		fire(target)

func _on_radar_area_entered(area: Area2D) -> void:
	target.append(area)


func _on_radar_area_exited(area: Area2D) -> void:
	target.erase(area)
