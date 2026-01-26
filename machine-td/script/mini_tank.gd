extends "res://script/enemy.gd"


func _ready():
	pass
	
func hurt(_num):
	hp-=_num
	lifeBar.value=hp
	if hp<0:
		ExplosionManage.playExplosion(global_position)
		Game.defeatEnemy.emit(reward)
		queue_free()

func _physics_process(delta):
	if points.size()==0:
		return 
	var target1 =points[pointIndex]
	if position.distance_to(target1) < 1:
		#print("====",pointIndex,points[pointIndex])
		pointIndex=wrapi(pointIndex+1, 0,points.size())
		target1 =points[pointIndex]
		if pointIndex==0:
			Game.enemyEscape.emit(lossPoints)
			queue_free()
	#vec = (target - position).normalized() * speed
	position+=position.direction_to(target1) * speed * delta
	base.look_at(target1)
