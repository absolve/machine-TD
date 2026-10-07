extends "res://script/enemy/enemy.gd"
## 维修车：推进型辅助敌人。


func _ready() -> void:
	parent = get_parent() as PathFollow2D
	setupEnemyInfo()


func fire(targets: Array) -> void:
	if canShot:
		canShot = false
		for i in targets:
			if is_instance_valid(i):
				i.addHp(atk)
		delayTimer.start()
		
func _physics_process(delta: float) -> void:
	if points.size() == 0:
		return
	parent.progress += speed * delta
	if parent.progress_ratio >= 1:
		Game.enemyEscaped.emit(lossPoints)
		_freeSelf()
	if target.size() > 0:
		fire(target)
