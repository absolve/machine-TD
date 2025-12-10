extends Node2D

var ex1=preload("res://scene/explosion.tscn")


func playExplosion(pos:Vector2):
	var temp=ex1.instantiate()
	temp.z_index=10
	temp.position=pos
	add_child(temp)
