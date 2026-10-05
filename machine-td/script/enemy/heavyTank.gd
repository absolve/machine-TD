extends "res://script/enemy/enemy.gd"


func _ready() -> void:
	parent = get_parent()
	setupEnemyInfo()

func _physics_process(delta: float) -> void:
	if points.size() == 0:
		return
	parent.progress += speed * delta
	if parent.progress_ratio >= 1:
		Game.enemyEscaped.emit(lossPoints)
		owner.queue_free()
		return
	var tower: Tower = pickTowerTarget()
	if tower != null and aimAt(tower, delta):
		attackTower(tower)
