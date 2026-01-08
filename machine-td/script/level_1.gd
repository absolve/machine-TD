extends "res://script/base_level.gd"

@onready var path1=$Path2D

func _ready():
	print(StageData.allStage)
	
	for i in StageData.allStage:
		if levelId==i.get("id"):
			wave=i.get("wave")
			health=i.get("health")
			money=i.get("money")
			enemyList=i.get("enemySpawner")
			break
	waveTimer.start(5)

func waveSpawner():
	if currentSpawner.size()>0:
		
		pass
	pass
	


func _on_wave_timer_timeout():
	print("_on_wave_timer_timeout")
	if currentSpawner.size()>0:
		waveTimer.start()
		return
	if currentSpawner.size()==0&&get_tree().get_nodes_in_group("enemy").size()>0:
		waveTimer.start()
		return
			
	currWave+=1
	if currWave>wave:
		print("end")
		return
	for i in enemyList:
		if int(i.time)==currWave:
			currentSpawner.push_back(i)
	if currentSpawner.size()>0:	
		spawnerTimer.start()		
	waveTimer.start()
	

func _on_spawner_timer_timeout():
	print("_on_spawner_timer_timeout")
	for i in currentSpawner:
		if i.number>0:
			if i.type==Game.enemyType.miniTank:
				var temp = StageData.minTank.instantiate()
				temp.points=path1.curve.get_baked_points()
				temp.position=temp.points[0]
				add_child(temp)
				i.number-=1
		else:
			currentSpawner.erase(i)		
	if currentSpawner.size()>0:
		spawnerTimer.start()
	
