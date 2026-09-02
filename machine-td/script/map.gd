extends Node2D

@onready var hud = $hud
#@onready var towerShadow = $towerShadow
@onready var titleNode = $hud/title
@onready var towerUINode = $hud/towerUI
@onready var resultScreen = $resultScreen
@onready var pauseMenu = $pauseMenu

@onready var finishTimer = $Timer
@onready var toastInfo = $hud/toastInfo
@onready var waveProgressBar = $hud/waveProgressBar

var level
var gunTower = preload("res://scene/machineGunTower.tscn")
var rocketTower = preload("res://scene/rocketTower.tscn")
var cannonTower = preload("res://scene/cannonTower.tscn")
var EMPTower = preload("res://scene/EMPTower.tscn")
var teslaCoilTower = preload("res://scene/teslaCoilTower.tscn")
var laserTower = preload("res://scene/laserTower.tscn")
var droneBase = preload("res://scene/droneBase.tscn")

var isLastWave = false # 最后一波
var cellSize = 64
var debug = true
var font
var selectedTower = null # 选中的塔


func _ready():
	print("map")
	Game.map = self
	#Game.selectTower.connect(selectTower)
	Game.placeTower.connect(placeTower)
	Game.refreshData.connect(refreshData)
	Game.defeatEnemy.connect(defeatEnemy)
	Game.enemyEscape.connect(enemyEscape)
	Game.sellTower.connect(sellTower)
	Game.lastWave.connect(lastWave)
	Game.clickTower.connect(clickTower)
	
	resultScreen.btnRestart.pressed.connect(restart)
	resultScreen.btnNextLevel.pressed.connect(nextLevel)
	resultScreen.btnMenu.pressed.connect(returnHome)
	pauseMenu.resumePressed.connect(resumeGame)
	pauseMenu.restartPressed.connect(restart)
	pauseMenu.menuPressed.connect(returnHome)
		
	#加载关卡
	loadLevel()
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Sfx"), UserData.sfxMuted)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Bg"), UserData.musicMuted)
	
	titleNode.hp = level.health
	titleNode.wave = level.wave
	titleNode.money = level.money
	syncWaveProgressBar()
	#titleNode.score=level.score
	titleNode.start.connect(startGame)
	titleNode.pause.connect(pauseGame)
	titleNode.soundOn.connect(soundOn)
	titleNode.soundOff.connect(soundOff)
	titleNode.musicOn.connect(musicOn)
	titleNode.musicOff.connect(musicOff)
	titleNode.home.connect(home)
	titleNode.speedOn.connect(speedOn)
	titleNode.speedOff.connect(speedOff)
	#queue_redraw()
	# print(int(1920.0 / cellSize))
	font = ThemeDB.fallback_font
	
#载入关卡
func loadLevel():
	var stage_id = StageData.currentStageId
	var stage_data: Dictionary = {}
	for s in StageData.allStage:
		if s.get("id") == stage_id:
			stage_data = s
			break
	if stage_data.is_empty():
		push_error("未找到关卡数据: id=" + str(stage_id))
		return
	var scene_path: String = stage_data.get("scene", "")
	if scene_path.is_empty():
		push_error("关卡未配置 scene 路径: id=" + str(stage_id))
		return
	var level_scene = load(scene_path)
	var level_instance = level_scene.instantiate()
	# 设置 levelId，使关卡 _ready() 自动加载对应数据（base_level._load_stage_data）
	level_instance.levelId = stage_id
	add_child(level_instance)
	level = level_instance
	syncWaveProgressBar()

func syncWaveProgressBar() -> void:
	if level == null or waveProgressBar == null:
		return
	var total_wave: float = max(float(level.wave), 1.0)
	var current_wave: float = 0.0
	if "currWave" in level:
		current_wave = float(level.currWave)
	waveProgressBar.maxProgress = total_wave
	waveProgressBar.set_progress(current_wave)

#选中塔
#func selectTower(item):
	#print(item)
	#var temp = Game.towerInfo.get(item)
	#towerShadow.cost = temp.cost
	#towerShadow.towerType = item
	#towerShadow.setActive()
	#for i in get_tree().get_nodes_in_group("placeableArea"):
		#i.isShow = true
	
#放着塔
func placeTower(type, cost, grid, towerCoverGrid, gridSize: Vector2i = Vector2i(1, 1)):
	print('placeTower', type, grid, towerCoverGrid, gridSize)
	if titleNode.money < cost:
		print('Insufficient funds')
		addNotice('Insufficient funds')
		return
	var temp = null
	titleNode.money -= cost
	if type == Game.towerType.machineGunTower:
		temp = gunTower.instantiate()
	elif type == Game.towerType.cannonTower:
		temp = cannonTower.instantiate()
	elif type == Game.towerType.rocketTower:
		temp = rocketTower.instantiate()
	elif type == Game.towerType.EMPTower:
		temp = EMPTower.instantiate()
	elif type == Game.towerType.teslaCoilTower:
		temp = teslaCoilTower.instantiate()
	elif type == Game.towerType.laserTower:
		temp = laserTower.instantiate()
	elif type == Game.towerType.droneBase:
		temp = droneBase.instantiate()

	var info = Game.towerInfo.get(type)
	temp.money = info.cost
	temp.sellingPrice = temp.money / 2
	temp.atk = info.atk
	temp.delay = info.reload
	temp.radarScope = info.scope
	temp.maxHp = int(info.get("maxHp", info.get("hp", 100)))
	temp.hp = int(info.get("hp", temp.maxHp))
	temp.initTime = info.get("initTime", temp.initTime)
	if temp.maxHp <= 0:
		temp.maxHp = max(1, temp.hp)
	if temp.hp <= 0:
		temp.hp = temp.maxHp
	
	# grid 是鼠标所在中心格,占用块的左上角格子 = grid - (W/2, H/2)
	# 块中心世界坐标 = top_left * cellSize + (W*cellSize, H*cellSize) / 2
	@warning_ignore("integer_division")
	var half: Vector2i = Vector2i(gridSize.x / 2, gridSize.y / 2)
	var top_left: Vector2i = grid - half
	var block_size: Vector2i = Vector2i(gridSize.x * cellSize, gridSize.y * cellSize)
	temp.position = Vector2(top_left * cellSize) + Vector2(block_size * 0.5)
	temp.coverGrid = towerCoverGrid
	level.addOccupiedArea(towerCoverGrid)
	add_child(temp)
	#level.setShadowHide()
	
		
#更新游戏中数据
func refreshData(dict):
	print(dict)
	if dict.hp:
		titleNode.hp = dict.hp
	if dict.wave:
		titleNode.wave = dict.wave
	if dict.money:
		titleNode.money = dict.money
	if dict.score:
		titleNode.score = dict.score
	syncWaveProgressBar()

#获得奖励
func defeatEnemy(point):
	titleNode.money += point

#敌人逃脱
func enemyEscape(point):
	if titleNode.hp - point < 0:
		print('game over')
		pauseGame()
		resultScreen.setResult(true)
		resultScreen.levelRating.rating = 0
		resultScreen.popup_centered()

	titleNode.hp -= point

func startGame():
	get_tree().paused = false
	level.start()
	syncWaveProgressBar()

func pauseGame():
	get_tree().paused = true
	if not pauseMenu.visible:
		pauseMenu.popup_centered()

func resumeGame():
	pauseMenu.hide()
	get_tree().paused = false

func soundOn():
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Sfx"), false)
	UserData.sfxMuted = false
	UserData.saveSettings()
	
func soundOff():
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Sfx"), true)
	UserData.sfxMuted = true
	UserData.saveSettings()
	
func musicOn():
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Bg"), false)
	UserData.musicMuted = false
	UserData.saveSettings()
	
func musicOff():
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Bg"), true)
	UserData.musicMuted = true
	UserData.saveSettings()

func home():
	pauseGame()

func speedOn():
	pass
	
func speedOff():
	pass

# 出售防御塔
func sellTower(money, coverGrid: Array[Vector2i]):
	print("sellTower ", money, coverGrid)
	level.removeOccupiedArea(coverGrid)
	titleNode.money += money

func lastWave():
	print('lastWave')
	isLastWave = true
	finishTimer.start()
	pass
	
func finish():
	#判断敌人是否生产完毕和所有敌人全部消灭，游戏结束
	if level.currentSpawner.size() > 0:
		finishTimer.start()
		return
	if get_tree().get_nodes_in_group("enemy").size() > 0:
		finishTimer.start()
		return
		
	#所有敌人都被消灭
	resultScreen.setResult(false)
	resultScreen.levelRating.rating = calculateStars()
	resultScreen.popup_centered()

# 根据基地剩余生命计算三档星级
func calculateStars() -> int:
	if titleNode.hp <= 0:
		return 0
	var health_ratio := float(titleNode.hp) / float(level.health)
	if health_ratio >= 1.0:
		return 3
	if health_ratio >= 0.5:
		return 2
	return 1

#添加通知
func addNotice(s, color: Color = Color.CORAL):
	toastInfo.display(s, color)

#选中塔
func clickTower(item, selected):
	if selected:
		selectedTower = item
	else:
		selectedTower = null

func restart():
	get_tree().paused = false
	get_tree().reload_current_scene.call_deferred()

func nextLevel():
	SceneTransition.change_scene("res://scene/level_select.tscn")

func returnHome():
	get_tree().paused = false
	SceneTransition.change_scene("res://scene/welcome.tscn")

func _physics_process(_delta: float) -> void:
	if debug:
		queue_redraw()
	

func _unhandled_input(_event):
	if _event.is_action_pressed("selectCancel"):
		for i in get_tree().get_nodes_in_group("placeableArea"):
			i.isShow = false
		#towerShadow.setInactive()
	if _event.is_action_pressed("click"):
		if selectedTower:
			selectedTower.hideSelect()

func _on_button_pressed():
	resultScreen.popup_centered()
	
	pass # Replace with function body.


func _draw() -> void:
	if debug:
		for i in range(int(1920.0 / cellSize) + 1):
			draw_line(Vector2(i * cellSize, 0), Vector2(i * cellSize, cellSize * (int(1920.0 / cellSize)) + 1), Color.GRAY, 1, true)
		for i in range(int(1080.0 / cellSize) + 1):
			draw_line(Vector2(0, i * cellSize), Vector2(cellSize * (int(1920.0 / cellSize) + 1), i * cellSize), Color.GRAY, 1, true)
		#for i in level.allowArea:
			#draw_rect(Rect2(Vector2(i.x * cellSize, i.y * cellSize),
			 #Vector2(cellSize, cellSize)), Color.SALMON)

		# 绘制鼠标位置信息
		var x = floor(get_local_mouse_position().x)
		var y = floor(get_local_mouse_position().y)
		# draw_string(font, get_local_mouse_position(), "%s-%s" % [x, y],
		# 	HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		draw_string(font, get_local_mouse_position() + Vector2(20, 20), "%s-%s" % [floori(x / cellSize),
		 floori(y / cellSize)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color.WHEAT)
