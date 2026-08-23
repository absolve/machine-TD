extends Node

const TileSize = 64  #网格大小

# 当前选中的关卡ID（由 level_select 点击时设置，map 读取后加载对应场景）
var currentStageId: int = 1

#关卡的数据
var allStage = [
	{
		'name': '1',
		"id": 1,
		'wave': 2,
		'health': 20,
		'money': 100,
		'scene': 'res://scene/level/level_1.tscn',
		"enemySpawner": [ {'time': 1, 'type': Game.enemyType.miniTank, 'number': 1},
		{'time': 2, 'type': Game.enemyType.miniTank, 'number': 2}]
	},
	{
		'name': '2',
		"id": 2,
		'wave': 2,
		'health': 20,
		'money': 300,
		'scene': 'res://scene/level/level_1.tscn',
		"enemySpawner": [ {'time': 1, 'type': Game.enemyType.miniTank, 'number': 1},
		{'time': 2, 'type': Game.enemyType.miniTank, 'number': 2}]
	},
]

var minTank = preload("res://scene/miniTank.tscn")
var mediumTank = preload("res://scene/medium_tank.tscn")
var heavyTank = preload("res://scene/heavy_tank.tscn")
