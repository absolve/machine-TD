extends "res://script/base_level.gd"

func _ready():
	super._ready()
	#print("level")
	#print(StageData.allStage)
	#print(get_node("placeableArea2/shape").shape.get_rect())
	#print( Rect2(get_node("placeableArea2").global_position-
	#get_node("placeableArea2/shape").shape.get_rect().size/2,
				#get_node("placeableArea2/shape").shape.get_rect().size) )
	#print(get_node("placeableArea2/shape").shape.get_rect())
	# for i in StageData.allStage:
	# 	if levelId == i.get("id"):
	# 		wave = i.get("wave")
	# 		health = i.get("health")
	# 		money = i.get("money")
	# 		enemyList = i.get("enemySpawner")
	# 		break
	#waveTimer.start(5)
	#Game.refreshData.emit({'wave':wave,'health':health,'money':money})
	allowArea.append_array([Vector2i(10,6),Vector2i(11,6),Vector2i(10,7),Vector2i(11,7)])
	
	


#func waveSpawner():
	#if currentSpawner.size() > 0:
		#pass
	#pass
