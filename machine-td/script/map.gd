extends Node2D

@onready var hud = $hud
#@onready var towerShadow = $towerShadow
@onready var titleNode = $hud/title
@onready var towerUINode = $hud/towerUI
@onready var resultScreen = $popupLayer/resultScreen
@onready var pauseMenu = $popupLayer/pauseMenu

@onready var finishTimer = $Timer
@onready var toastInfo = $hud/toastInfo
@onready var waveProgressBar = $hud/waveProgressBar
@onready var towerDetailPanel = $hud/towerDetailPanel
@onready var enemyDetailPanel = $hud/enemyDetailPanel
@onready var levelIntroPanel = $popupLayer/levelIntroPanel
@onready var achievementTracker = $achievementTracker
@onready var abilityBar = $hud/abilityBar
@onready var customCamera = $customCamera

var level
var gunTower = preload("res://scene/tower/machineGunTower.tscn")
var rocketTower = preload("res://scene/tower/rocketTower.tscn")
var cannonTower = preload("res://scene/tower/cannonTower.tscn")
var EMPTower = preload("res://scene/tower/EMPTower.tscn")
var teslaCoilTower = preload("res://scene/tower/teslaCoilTower.tscn")
var laserTower = preload("res://scene/tower/laserTower.tscn")
var droneBase = preload("res://scene/tower/droneBase.tscn")

var isLastWave = false # 最后一波
var cellSize = 64
var debug = false
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
	Game.repairTower.connect(repairTower)
	Game.lastWave.connect(lastWave)
	Game.clickTower.connect(clickTower)
	Game.clickEnemy.connect(clickEnemy)
	Game.towerLocked.connect(onTowerLocked)
	# 技能选中的范围预览圈由 map 的 _draw 画；取消时也必须重绘，否则圈会残留
	AbilityManager.selection_started.connect(_on_ability_selection_changed)
	AbilityManager.selection_ended.connect(_on_ability_selection_changed)
	
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
	# 按关卡配置启用能力技能
	setup_abilities()

#按关卡配置启用能力技能（未配置的关卡不显示技能条）
func setup_abilities() -> void:
	var stage_id := int(stageData.get("id", StageData.currentStageId))
	var ability_ids: Array = StageData.getAbilities(stage_id)
	AbilityManager.begin_battle(ability_ids)
	if abilityBar:
		abilityBar.setup(ability_ids)

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
	# 复位相机：回到「整关刚好铺满」，避免上一关放大/拖动后带过来
	customCamera.reset_view()

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
	# 兜底：本关不放行的塔一律拒绝（tower_ui 已经把卡片置灰，这里防止绕过）
	if not StageData.isTowerAllowed(StageData.currentStageId, type):
		addNotice(tr("_TowerLockedInStage"))
		return
	if titleNode.money < cost:
		print('Insufficient funds')
		addNotice(tr("_NotEnoughMoney"))
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
	resultScreen.show()

func startGame():
	get_tree().paused = false
	# 顶栏 ▶/⏸ 同步成「正在运行」（= 显示暂停图，点一下才暂停）
	titleNode.set_playing(true)
	level.start()
	syncWaveProgressBar()

func pauseGame():
	get_tree().paused = true
	titleNode.set_playing(false)
	if not pauseMenu.visible:
		pauseMenu.show()

func resumeGame():
	pauseMenu.hide()
	get_tree().paused = false
	titleNode.set_playing(true)

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

# 修理防御塔：扣费成功后把血量回满
func repairTower(cost: int, tower: Node) -> void:
	if not is_instance_valid(tower):
		return
	if titleNode.money < cost:
		addNotice(tr("_NotEnoughMoney"))
		return
	titleNode.money -= cost
	tower.apply_repair()
	if towerDetailPanel:
		towerDetailPanel.refresh()

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
	resultScreen.show()

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

# 玩家点了本关禁用的塔卡片
func onTowerLocked() -> void:
	addNotice(tr("_TowerLockedInStage"))

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
	# 选择技能目标时也要重绘，让范围预览跟着鼠标走
	if debug or AbilityManager.is_selecting_position():
		queue_redraw()


# 技能选中 / 取消都要重绘一次。
# ⚠️ 取消时如果不重绘，_physics_process 里的条件变假 → 再也不调 _draw，
#    最后一帧画的范围预览圈就会一直留在画布上（黄色的圈不消失）。
func _on_ability_selection_changed(_ability_id: String) -> void:
	queue_redraw()
	

func _unhandled_input(_event):
	# 正在等待技能目标时，这一击只用于确认/取消技能，不再走原来的取消逻辑
	if AbilityManager.is_selecting():
		if _event.is_action_pressed("click"):
			_confirm_ability_target()
			return
		if _event.is_action_pressed("selectCancel"):
			AbilityManager.cancel_selecting()
			return
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


# 确认技能目标：范围类技能直接用鼠标位置
func _confirm_ability_target() -> void:
	AbilityManager.confirm_target(get_global_mouse_position())


# 收集范围内自己的防御塔（塔直接挂在 map 下）
func _get_towers_in_radius(center: Vector2, radius: float) -> Array[Tower]:
	var result: Array[Tower] = []
	for child in get_children():
		if not (child is Tower) or not is_instance_valid(child):
			continue
		if (child as Tower).global_position.distance_to(center) <= radius:
			result.append(child)
	return result


# 区域轰炸：对范围内所有敌人造成伤害，并用提示反馈命中数量
func area_damage(center: Vector2, radius: float, damage: int) -> bool:
	if radius <= 0.0 or damage <= 0:
		return false
	var hit_count := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(center) > radius:
			continue
		if enemy.has_method("hurt"):
			enemy.hurt(damage, null, "energy")
			hit_count += 1
	ExplosionManage.playExplosion(center)
	if hit_count > 0:
		addNotice(_t("_ability_bombard_hit", "Airstrike hit %d enemies") % hit_count, Color(1.0, 0.776, 0.102))
	else:
		addNotice(_t("_ability_bombard_miss", "Airstrike hit nothing"), Color(0.86, 0.92, 0.95))
	return true


# 塔无敌：让范围内所有防御塔在一段时间内免疫伤害
func area_invincible(center: Vector2, radius: float, duration: float) -> bool:
	if radius <= 0.0 or duration <= 0.0:
		return false
	var towers := _get_towers_in_radius(center, radius)
	for tower in towers:
		tower.set_invincible(duration)
	if towers.is_empty():
		addNotice(_t("_ability_invincible_miss", "No tower in range"), Color(0.86, 0.92, 0.95))
	else:
		addNotice(_t("_ability_invincible_hit", "%d towers are now invincible") % towers.size(), Color(1.0, 0.776, 0.102))
	return true


# 取翻译；语言文件未导入该 key 时回退到默认英文文本
func _t(key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	var translated := tr(key)
	return fallback if translated == key else translated

func _on_button_pressed():
	# 地图内按钮用 ui_confirm（区别于菜单里的 coin）
	SoundManage.playConfirm()
	resultScreen.show()
	
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

	# 技能范围预览：等待玩家点位置时，跟着鼠标画一个安全黄圆圈
	if AbilityManager.is_selecting_position():
		var radius := AbilityManager.get_selecting_radius()
		if radius > 0.0:
			var mouse_pos := get_local_mouse_position()
			var circle_color := Color(1.0, 0.776, 0.102, 1.0)
			draw_circle(mouse_pos, radius, Color(circle_color.r, circle_color.g, circle_color.b, 0.16))
			draw_arc(mouse_pos, radius, 0.0, TAU, 64, Color(circle_color.r, circle_color.g, circle_color.b, 0.9), 3.0)
