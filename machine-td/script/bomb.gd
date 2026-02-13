extends Area2D


@onready var aniNode = $ani

var blastRadius = 50 # 爆炸范围
var objList = []
var damage = 40 # 伤害
var hasDamage = false


func _ready():
	aniNode.play("default")
	

func _physics_process(_delta):
	if hasDamage:
		for i in objList:
			if i is Enemy:
				i.hurt(damage)
		hasDamage = false

 
func _on_area_shape_exited(_area_rid: RID, area: Area2D, _area_shape_index: int, _local_shape_index: int):
	objList.erase(area)


func _on_area_shape_entered(_area_rid: RID, area: Area2D, _area_shape_index: int, _local_shape_index: int):
	objList.append(area)


func _on_ani_frame_changed():
	if aniNode.frame==1:
		hasDamage=true


func _on_ani_animation_finished():
	queue_free()
