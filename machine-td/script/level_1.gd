extends "res://script/base_level.gd"

@onready var path1 = $Path2D

func _ready():
	print("level")
	#print(StageData.allStage)
	#print(get_node("placeableArea2/shape").shape.get_rect())
	#print( Rect2(get_node("placeableArea2").global_position-
	#get_node("placeableArea2/shape").shape.get_rect().size/2,
				#get_node("placeableArea2/shape").shape.get_rect().size) )
	#print(get_node("placeableArea2/shape").shape.get_rect())
	for i in StageData.allStage:
		if levelId == i.get("id"):
			wave = i.get("wave")
			health = i.get("health")
			money = i.get("money")
			enemyList = i.get("enemySpawner")
			break
	#waveTimer.start(5)
	#Game.refreshData.emit({'wave':wave,'health':health,'money':money})

func waveSpawner():
	if currentSpawner.size() > 0:
		pass
	pass

#开始产生
func start():
	waveTimer.start()


func _on_wave_timer_timeout():
	print("_on_wave_timer_timeout")
	if currentSpawner.size() > 0:
		waveTimer.start()
		return
	if currentSpawner.size() == 0 && get_tree().get_nodes_in_group("enemy").size() > 0:
		waveTimer.start()
		return
			
	currWave += 1
	if currWave > wave:
		print("end")
		return
	for i in enemyList:
		if int(i.time) == currWave:
			currentSpawner.push_back(i)
	if currentSpawner.size() > 0:
		spawnerTimer.start()
	waveTimer.start()
	

func _on_spawner_timer_timeout():
	print("_on_spawner_timer_timeout")
	for i in currentSpawner:
		if i.number > 0:
			if i.type == Game.enemyType.miniTank:
				var temp = StageData.minTank.instantiate()
				temp.points = path1.curve.get_baked_points()
				temp.position = temp.points[0]
				add_child(temp)
				i.number -= 1
		else:
			currentSpawner.erase(i)
	if currentSpawner.size() > 0:
		spawnerTimer.start()
