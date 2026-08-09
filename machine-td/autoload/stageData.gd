extends Node

const TileSize = 64  #网格大小

#关卡的数据
var allStage = [
	{
		'name': 'stage-1',
		"id": 1,
		'wave': 2,
		'health': 20,
		'money': 100,
		"enemySpawner": [ {'time': 1, 'type': Game.enemyType.miniTank, 'number': 1},
		{'time': 2, 'type': Game.enemyType.miniTank, 'number': 2}]
	},
	{
		'name': 'stage-2',
		"id": 2,
		'wave': 2,
		'health': 20,
		'money': 300,
		"enemySpawner": [ {'time': 1, 'type': Game.enemyType.miniTank, 'number': 1},
		{'time': 2, 'type': Game.enemyType.miniTank, 'number': 2}]
	},
]

var minTank = preload("res://scene/miniTank.tscn")
var mediumTank = preload("res://scene/medium_tank.tscn")
var heavyTank = preload("res://scene/heavy_tank.tscn")
