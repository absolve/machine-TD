extends Node

enum bulletType{
	player,enemy
}

enum enemyType{
	miniTank,
}

signal defeatEnemy  #击败敌人

var map=null

func addObj(obj):
	if map:
		map.add_child(obj)
