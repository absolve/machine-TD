extends Node

enum bulletType{
	player,enemy
}

enum enemyType{
	miniTank,
}

enum towerType{
	gunTower=1000,cannonTower,rocketTower
}

const towerInfo={
	towerType.gunTower:{
	"name":"gunTower",
	"atk":10,
	"cost":10,
	"reload":0.1,
	"desc":"Standard Machine Gun Tower",
	},
	towerType.cannonTower:{
	"name":"cannonTower",
	"atk":30,
	"cost":10,
	"reload":0.3,
	"desc":"",
	},
	towerType.rocketTower:{
	"name":"rocketTower",
	"atk":50,
	"cost":10,
	"reload":0.1,
	"desc":"",
	}
}



@warning_ignore("unused_signal")
signal defeatEnemy  #击败敌人
@warning_ignore("unused_signal")
signal enemyEscape #敌人逃脱
@warning_ignore("unused_signal")
signal selectTower #选择塔

var map=null

func addObj(obj):
	if map:
		map.add_child(obj)
