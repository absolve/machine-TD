extends "res://script/base_level.gd"


func _ready():
	print(StageData.allStage)
	
	for i in StageData.allStage:
		if levelId==i.get("id"):
			wave=i.get("wave")
			health=i.get("health")
			money=i.get("money")
			enemyList=i.get("enemySpawner")
			break


	
