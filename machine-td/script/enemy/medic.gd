extends "res://script/enemy/enemy.gd"
#维修车 敌人


func _ready():
	parent = get_parent()
	setupEnemyInfo()


func fire(t):
	if canShot:
		canShot = false
		for i in t:
			if is_instance_valid(i):
				i.addHp(atk)
		delayTimer.start()
		
func _physics_process(_delta):
	if points.size() == 0:
		return
	parent.progress += speed * _delta
	if parent.progress_ratio >= 1:
		Game.enemyEscaped.emit(lossPoints)
		owner.queue_free()
	if target.size() > 0:
		fire(target)
