extends Node

#关卡的数据
var allStage=[
	{
		'name':'stage-1',
		"id":1,
		'wave':2,
		'health':20,
		'money':300,
		"enemySpawner":[{'time':1,'type':Game.enemyType.miniTank,'number':1},
		{'time':2,'type':Game.enemyType.miniTank,'number':2}]
	}
]

var minTank=preload("res://scene/miniTank.tscn")
