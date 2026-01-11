extends Node

enum bulletType{
	player,enemy
}

enum enemyType{
	miniTank,
}

enum towerType{
	gunTower,cannonTower,rocketTower
}

@warning_ignore("unused_signal")
signal defeatEnemy  #击败敌人
@warning_ignore("unused_signal")
signal enemyEscape #敌人逃脱


var map=null

func addObj(obj):
	if map:
		map.add_child(obj)
