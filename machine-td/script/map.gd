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
@onready var towerDetailPanel = $hud/towerDetailPanel
@onready var enemyDetailPanel = $hud/enemyDetailPanel
@onready var levelIntroPanel = $levelIntroPanel
@onready var achievementTracker = $achievementTracker

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
var stageData: Dictionary = {} # 当前关卡配置（用于关卡情报弹窗）
# 最近一次“选中敌人”的时刻(毫秒)：用于避免同一击又被 _unhandled_input 当成点空地而立刻取消
var _enemy_click_msec := -1000


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
	Game.clickEnemy.connect(clickEnemy)
	
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
	titleNode.score = UserData.score
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
	# 地图加载完成后弹出关卡情报，方便玩家查看本关敌人类型
	show_level_intro()

#显示关卡情报弹窗（关卡名 + 本关敌人类型等信息）
func show_level_intro() -> void:
	if levelIntroPanel == null:
		return
	levelIntroPanel.show_level(stageData)
	
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
	stageData = stage_data
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
	temp.type = type
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
	# 记录本局用过的塔类型（全域火力成就）
	if achievementTracker:
		achievementTracker.record_tower_built(type)
	#level.setShadowHide()
	
		
#更新游戏中数据
func refreshData(dict):
	print(dict)
	if dict.get("hp") != null:
		titleNode.hp = dict.hp
	if dict.get("wave") != null:
		titleNode.currentWave = dict.wave
	if dict.get("money") != null:
		titleNode.money = dict.money
	if dict.get("score") != null:
		titleNode.score = dict.score
	syncWaveProgressBar()

#获得奖励
func defeatEnemy(point):
	titleNode.money += point

#敌人逃脱
func enemyEscape(point):
	# 先扣血再判定：hp 归零（而不是变成负数）就算基地被打爆
	titleNode.hp = maxi(0, titleNode.hp - point)
	if titleNode.hp <= 0:
		_on_defense_failed()

# 基地被打爆：直接进入失败结算
# 这里刻意不调用 pauseGame()，否则暂停菜单会和结算窗叠在一起
func _on_defense_failed() -> void:
	if resultScreen.visible:
		return
	get_tree().paused = true
	resultScreen.setResult(true)
	resultScreen.levelRating.rating = 0
	resultScreen.setGemReward(0)
	resultScreen.popup_centered()

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
		
	#所有敌人都被消灭，记录最高评分、奖励和下一关解锁状态
	var rating = calculateStars()
	# rating 为 0 表示基地已经被打爆，不算通关：不写星级、不解锁关卡、不发宝石
	# （失败结算已经在 _on_defense_failed() 里弹过了，这里直接结束）
	if rating <= 0:
		return
	record_achievements(rating)
	var gem_reward := UserData.recordStageCompletion(StageData.currentStageId, rating)
	titleNode.score = UserData.score
	resultScreen.setResult(false)
	resultScreen.levelRating.rating = rating
	resultScreen.setGemReward(gem_reward)
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

# 通关结算时提交成就进度
# rating 为 0 表示基地被打爆，不算通关，不记录任何通关类成就
func record_achievements(rating: int) -> void:
	if achievementTracker == null or rating <= 0:
		return
	# 基地全程没掉血 <=> 没有任何敌人逃脱
	var flawless: bool = titleNode.hp >= level.health
	achievementTracker.record_stage_cleared(StageData.currentStageId, flawless, _is_multi_route_level())

# 关卡是否有多条行军路线（存在多条 Path2D）
func _is_multi_route_level() -> bool:
	if level == null:
		return false
	var path_count := 0
	for child in level.get_children():
		if child is Path2D:
			path_count += 1
			if path_count > 1:
				return true
	return false

#添加通知
func addNotice(s, color: Color = Color.CORAL):
	toastInfo.display(s, color)

#选中塔
func clickTower(item, selected):
	if selected:
		# 右侧信息面板同一时间只服务一个目标：选中塔时收起敌人面板
		clearEnemyDetail()
		# 保持同一时间只选中一座塔，先取消之前选中的
		if selectedTower != null and selectedTower != item and is_instance_valid(selectedTower):
			var oldTower = selectedTower
			selectedTower = null # 先清空，避免 hideSelect 触发的回调把状态弄乱
			oldTower.hideSelect()
		selectedTower = item
		if towerDetailPanel:
			towerDetailPanel.show_tower(item)
	else:
		if selectedTower == item:
			selectedTower = null
		if towerDetailPanel:
			towerDetailPanel.clear()

#选中敌人（由 enemy.gd 的 input_event 触发）
# 敌人与塔共用屏幕右侧同一个信息面板槽位，两者互斥：选中敌人会先取消已选中的塔
func clickEnemy(enemy):
	if enemy == null or not is_instance_valid(enemy):
		return
	_enemy_click_msec = Time.get_ticks_msec()
	# 再次点击同一个敌人 -> 取消选中
	if enemyDetailPanel and enemyDetailPanel.visible and enemyDetailPanel.enemy == enemy:
		enemyDetailPanel.clear()
		return
	_deselectTower()
	if enemyDetailPanel:
		enemyDetailPanel.show_enemy(enemy)

# 收起敌人信息面板
func clearEnemyDetail():
	if enemyDetailPanel:
		enemyDetailPanel.clear()

# 取消当前选中的塔（不递归触发敌人选中）
func _deselectTower():
	if selectedTower != null and is_instance_valid(selectedTower):
		var oldTower = selectedTower
		selectedTower = null # 先清空，避免 hideSelect 触发的回调把状态弄乱
		oldTower.hideSelect()

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
		# 这一击若刚选中了敌人，就不要再当成“点空地”把面板取消掉
		if Time.get_ticks_msec() - _enemy_click_msec > 150:
			clearEnemyDetail()
		if selectedTower and is_instance_valid(selectedTower):
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
