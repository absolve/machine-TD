extends "res://script/enemy.gd"


func _ready():
	speed=100
	
func hurt(_num):
	hp-=_num
	lifeBar.setValue(hp)
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
	#vec = (target - position).normalized() * speed
	position+=position.direction_to(target1) * speed * delta
	base.look_at(target1)
