extends Node

enum bulletType{
	player,enemy
}


var map=null

func addObj(obj):
	if map:
		map.add_child(obj)
