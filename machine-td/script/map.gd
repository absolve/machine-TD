extends Node2D

## 无尽模式的关卡场景（与 15 个关卡平级，见 endless_mode_design.md）
const ENDLESS_LEVEL_SCENE := "res://scene/level/endless.tscn"

## 教程关的关卡 id（StageData.allStage 里 'id': 0 那条）
const TUTORIAL_STAGE_ID := 0
## 教程关的新手引导（**只有教程关**会实例化它，见 setupTutorialGuide）
const TUTORIAL_GUIDE_SCENE := "res://scene/tutorial_guide.tscn"

## 无尽结算要写进结算面板的那行文字（普通关卡用不到，一直是空串）
var endlessStatsText: String = ""

@onready var hud = $Hud
#@onready var towerShadow = $TowerShadow
@onready var titleNode = $Hud/title
@onready var towerUINode = $Hud/towerUI
@onready var resultScreen = $PopupLayer/resultScreen
@onready var pauseMenu = $PopupLayer/pauseMenu

@onready var finishTimer = $Timer
@onready var toastInfo = $Hud/toastInfo
@onready var waveProgressBar = $Hud/waveProgressBar
@onready var towerDetailPanel = $Hud/towerDetailPanel
@onready var enemyDetailPanel = $Hud/enemyDetailPanel
@onready var levelIntroPanel = $PopupLayer/levelIntroPanel
## 战斗开始横幅（独立场景）。关卡**第一次**开打时闪一下提示玩家
@onready var battleStartBanner = $PopupLayer/battleStartBanner
@onready var achievementTracker = $AchievementTracker
@onready var abilityBar = $Hud/abilityBar
@onready var customCamera = $CustomCamera

## 教程关的新手引导实例（非教程关一直是 null）
var tutorialGuide: Node = null

var level
var gunTower = preload("res://scene/tower/machineGunTower.tscn")
var rocketTower = preload("res://scene/tower/rocketTower.tscn")
var cannonTower = preload("res://scene/tower/cannonTower.tscn")
var EMPTower = preload("res://scene/tower/EMPTower.tscn")
var teslaCoilTower = preload("res://scene/tower/teslaCoilTower.tscn")
var laserTower = preload("res://scene/tower/laserTower.tscn")
var droneBase = preload("res://scene/tower/droneBase.tscn")
var ironBox = preload("res://scene/tower/ironBox.tscn")

var isLastWave = false # 最后一波
## 结算复查开关：lastWave() 打开，finish() 复查到"敌人全清"后关闭并弹结算。
## 没有它的话，暂停/失败后 Timer 仍会周期性回调 finish()，可能重复结算。
var finishChecking: bool = false
## 结算完成标记：真正弹过一次结算后置 true，之后 finish() / lastWaveStarted 一律短路。
## 兜底防止"重复的 lastWaveStarted"把宝石行从 "+N" 覆盖成"已领取"，并重复累加通关分数。
var settled: bool = false
var cellSize = 64
var debug = false
var font
var selectedTower = null # 选中的塔
var stageData: Dictionary = {} # 当前关卡配置（用于关卡情报弹窗）
# 最近一次“选中敌人”的时刻(毫秒)：用于避免同一击又被 _unhandled_input 当成点空地而立刻取消
var enemyClickMsec: int = -1000


func _ready():
	print("map")
	Game.map = self
	#Game.selectTower.connect(selectTower)
	Game.towerPlaced.connect(placeTower)
	Game.dataRefreshed.connect(refreshData)
	Game.enemyRewarded.connect(onEnemyDefeated)
	Game.gemRewarded.connect(onGemRewarded)
	Game.enemyEscaped.connect(onEnemyEscaped)
	Game.towerSold.connect(onTowerSold)
	# 塔被打爆时也要归还格子（出售那条路已经在 sellTower 里还款+归还了）
	Game.towerGridReleased.connect(onTowerGridReleased)
	Game.towerRepaired.connect(onTowerRepaired)
	Game.lastWaveStarted.connect(onLastWaveStarted)
	Game.towerClicked.connect(onTowerClicked)
	Game.enemyClicked.connect(onEnemyClicked)
	Game.towerLocked.connect(onTowerLocked)
	# 技能选中的范围预览圈由 map 的 _draw 画；取消时也必须重绘，否则圈会残留
	AbilityManager.selectionStarted.connect(onAbilitySelectionChanged)
	AbilityManager.selectionEnded.connect(onAbilitySelectionChanged)
	# 技能花掉宝石后刷新顶栏数字
	AbilityManager.gemChanged.connect(onGemChanged)
	AbilityManager.abilityFailed.connect(onAbilityFailed)
	
	resultScreen.btnRestart.pressed.connect(restart)
	resultScreen.btnNextLevel.pressed.connect(nextLevel)
	resultScreen.btnMenu.pressed.connect(returnHome)
	pauseMenu.resumePressed.connect(resumeGame)
	pauseMenu.restartPressed.connect(restart)
	pauseMenu.menuPressed.connect(returnHome)
	# 无尽模式：暂停里允许主动结束本局（普通关卡该按钮隐藏）
	pauseMenu.giveUpPressed.connect(onEndlessGiveUp)
		
	loadLevel()
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Sfx"), UserData.sfxMuted)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Bg"), UserData.musicMuted)
	
	titleNode.hp = level.health
	titleNode.wave = level.wave
	titleNode.money = level.money
	titleNode.score = UserData.score
	# 波次进度条暂时用不上（无尽模式没有总波数），先整条隐藏 ——
	# 需要恢复时把下面这行删掉，并还原 syncWaveProgressBar() 的调用即可。
	if waveProgressBar:
		waveProgressBar.visible = false
	#titleNode.score=level.score
	titleNode.started.connect(startGame)
	titleNode.paused.connect(pauseGame)
	titleNode.soundOnPressed.connect(onSoundOnPressed)
	titleNode.soundOffPressed.connect(onSoundOffPressed)
	titleNode.musicOnPressed.connect(onMusicOnPressed)
	titleNode.musicOffPressed.connect(onMusicOffPressed)
	titleNode.homePressed.connect(onHomePressed)
	titleNode.speedOnPressed.connect(onSpeedOnPressed)
	titleNode.speedOffPressed.connect(onSpeedOffPressed)
	#queue_redraw()
	# print(int(1920.0 / cellSize))
	font = ThemeDB.fallback_font
	# 情报弹窗一关，就提示玩家去点顶栏的开始按钮
	if levelIntroPanel != null:
		levelIntroPanel.closed.connect(onIntroClosed)
	# 地图加载完成后弹出关卡情报，方便玩家查看本关敌人类型
	showLevelIntro()
	# 按关卡配置启用能力技能
	setupAbilities()
	# 教程关的新手引导（单独场景，只有教程关会实例化；情报弹窗关掉后才现身）
	setupTutorialGuide()


## 本关是否已经开打过。只有第一次点开始才闪横幅，暂停后继续不闪
var battleStarted: bool = false


## 未配置技能的关卡不创建技能条，避免显示空控件。
func setupAbilities() -> void:
	var stageId: int = int(stageData.get("id", StageData.currentStageId))
	# 无尽模式：两个技能都开（普通关卡按 StageData.stageAbilities 配置）
	var abilityIds: Array = (["bombard", "invincible"] if Game.endlessMode
		else StageData.getAbilities(stageId))
	AbilityManager.beginBattle(abilityIds)
	if abilityBar:
		abilityBar.setup(abilityIds)


## ── 教程关的新手引导 ──
## 单独一个场景（scene/tutorial_guide.tscn），**只有教程关**会实例化它：
## 其它关卡连这个场景都不会被加载，所以普通关卡的逻辑一行都不用改。
##
## ⚠️ 必须在 setupAbilities() **之后**调用 —— 引导要检查技能条里有没有技能槽
##   （宝石不够时它会自动省掉“放技能”那一步，免得玩家卡在一个做不完的任务上）。
func setupTutorialGuide() -> void:
	if Game.endlessMode or int(stageData.get("id", -1)) != TUTORIAL_STAGE_ID:
		return
	var scene: PackedScene = load(TUTORIAL_GUIDE_SCENE)
	if scene == null:
		push_error("加载教程引导失败: " + TUTORIAL_GUIDE_SCENE)
		return
	var layer: Node = scene.instantiate()
	add_child(layer)
	# ⚠️ 引导场景的根是 **CanvasLayer**（它负责“永远画在相机之上、不吃相机变换”），
	#    脚本挂在它里面那层 Root 控件上 —— CanvasLayer 既没有 size 也没有 _draw，
	#    遮罩必须由 Control 来画。所以这里要往里找一层，**不能**对着根节点调 setup()。
	tutorialGuide = findGuideRoot(layer)
	if tutorialGuide == null:
		push_error("教程引导场景结构不对：找不到带 setup() 的节点")
		return
	tutorialGuide.setup(self)
	# 关卡情报弹窗还开着就先等它关（onIntroClosed 会接力 start()）；
	# 没有弹窗的关卡（理论上教程有，但别赌）就直接开始。
	if levelIntroPanel == null or not levelIntroPanel.visible:
		startTutorialGuide()


## 找到引导场景里“带脚本的那一层”（根自己带脚本就返回根；否则找第一层子节点）。
## 不写死节点名，改名也不会悄悄坏掉 —— 找不到才报错。
func findGuideRoot(node: Node) -> Node:
	if node == null:
		return null
	if node.has_method("setup"):
		return node
	for child in node.get_children():
		if child.has_method("setup"):
			return child
	return null


## 开始（或接力开始）教程引导。重复调用是安全的 —— 引导自己会去重。
func startTutorialGuide() -> void:
	if tutorialGuide != null:
		tutorialGuide.start()


## ── 第 1 关的「工具箱在哪」提示 ──
##
## 为什么需要：教程引导只有教程关会走（map.gd::setupTutorialGuide 里判 stage id），
## 而**很多人根本不玩教程关**，直接点「开始游戏」进第 1 关 —— 于是不知道左上角那个
## 工具箱图标要点开才能建塔。这里在第 1 关给一个和「▶ 呼吸提示」同款的闪烁，指着工具箱。
##
## 只在第 1 关、且**玩家还没打通第 1 关**时出现：
##   · 老玩家（第 1 关已有星级记录）不再被打扰
##   · 无尽模式不提示（那一关的规则不一样，也没有关卡 id）
## 玩家点开工具箱后提示自己消失（见 tower_ui.gd::onIconGuiInput）。
##
## `pendingToolboxHint` 的作用：`showLevelIntro()` 里弹窗一开就调用了本函数，
## 但那时玩家正在看情报弹窗，两处一起闪会分散注意力。所以先记一笔，
## 等弹窗关掉（onIntroClosed）再真正亮起来。
## 没有情报弹窗的关卡则在 showLevelIntro() 里直接亮。
var pendingToolboxHint: bool = false


## 记录"本关该不该给工具箱提示"。真正的闪烁交给 startToolboxHintNow()。
func startToolboxHint() -> void:
	if Game.endlessMode:
		return
	# 只提示第 1 关；教程关有自己的引导，其它关卡玩家早已上手
	if int(stageData.get("id", -1)) != 1:
		return
	# 已经打通第 1 关的老玩家：他显然知道工具箱在哪，别打扰
	if UserData.getStageRating(1) > 0:
		return
	pendingToolboxHint = true


## 真正亮起工具箱提示（情报弹窗关掉之后，或本来就没有弹窗时）。
func startToolboxHintNow() -> void:
	if not pendingToolboxHint:
		return
	pendingToolboxHint = false
	if towerUINode != null and towerUINode.has_method("promptToolbox"):
		towerUINode.promptToolbox()


func showLevelIntro() -> void:
	# 无尽模式：用同一个情报面板，但内容是"规则 + 最高记录"（不读关卡数据）
	if Game.endlessMode:
		if levelIntroPanel == null:
			titleNode.promptStart()
			return
		levelIntroPanel.showEndless(UserData.endlessBestWave)
		return
	if levelIntroPanel == null:
		# 没有弹窗的关卡（比如教程）直接就开始提示玩家点开始
		titleNode.promptStart()
		# 没有情报弹窗挡着，工具箱提示可以立刻亮起来
		startToolboxHintNow()
		return
	levelIntroPanel.showLevel(stageData)
	# ⚠️ 这里**不要**再写 `pendingToolboxHint = true`。
	#    该不该提示已经由 loadLevel() -> startToolboxHint() 判过了（只在第 1 关、
	#    且玩家还没打通时才会置位）。早先这里多了一句无条件赋值，把关卡判断整个
	#    覆盖掉，导致**每一关**都在闪工具箱 —— 探针抓到的就是这个。


# 情报关闭后提示玩家开战，避免首屏直接进入战斗。
func onIntroClosed() -> void:
	titleNode.promptStart()
	# 教程关：情报读完就该现身了（此刻地图已经建好、技能条也已就位）
	startTutorialGuide()
	# 第 1 关：顺手给没玩过教程的玩家指一下工具箱在哪
	startToolboxHintNow()
	
func loadLevel():
	# 无尽模式：不走 allStage 查表，直接加载独立关卡场景
	if Game.endlessMode:
		loadEndlessLevel()
		return
	var stageId = StageData.currentStageId
	var stage_data: Dictionary = {}
	for s in StageData.allStage:
		if s.get("id") == stageId:
			stage_data = s
			break
	if stage_data.is_empty():
		push_error("未找到关卡数据: id=" + str(stageId))
		return
	stageData = stage_data
	var scenePath: String = stage_data.get("scene", "")
	if scenePath.is_empty():
		push_error("关卡未配置 scene 路径: id=" + str(stageId))
		return
	var levelScene = load(scenePath)
	var levelInstance = levelScene.instantiate()
	# 设置 levelId，使关卡 _ready() 自动加载对应数据（base_level._load_stage_data）
	levelInstance.levelId = stageId
	add_child(levelInstance)
	level = levelInstance
	# syncWaveProgressBar()
	# 复位相机：回到「整关刚好铺满」，避免上一关放大/拖动后带过来
	customCamera.resetView()
	startToolboxHint()

## 无尽模式：加载独立关卡场景（设计见 endless_mode_design.md）。
## 数值由关卡脚本自己定（10 血 / 400 金），所以 levelId 传 -1 ——
## base_level._ready() 在 allStage 里匹配不到 -1，就不会覆盖脚本里的值。
func loadEndlessLevel() -> void:
	var levelScene: PackedScene = load(ENDLESS_LEVEL_SCENE)
	if levelScene == null:
		push_error("加载无尽关卡失败: " + ENDLESS_LEVEL_SCENE)
		return
	stageData = {}
	var levelInstance = levelScene.instantiate()
	levelInstance.levelId = -1
	add_child(levelInstance)
	level = levelInstance
	customCamera.resetView()


# 波次进度条暂时停用（连带上面的节点隐藏与各处调用一起注释）：
#func syncWaveProgressBar() -> void:
#	if level == null or waveProgressBar == null:
#		return
#	var totalWave: float = max(float(level.wave), 1.0)
#	var currentWave: float = 0.0
#	if "currWave" in level:
#		currentWave = float(level.currWave)
#	waveProgressBar.maxProgress = totalWave
#	waveProgressBar.setProgress(currentWave)

# 旧选塔逻辑已迁移到 onTowerClicked，保留此段仅供对照。
#func selectTower(item):
	#print(item)
	#var temp = Game.towerInfo.get(item)
	#towerShadow.cost = temp.cost
	#towerShadow.towerType = item
	#towerShadow.setActive()
	#for i in get_tree().get_nodes_in_group("placeableArea"):
		#i.isShow = true
	
# 先校验建造条件，避免无效建造造成资源损失。
func placeTower(type, cost, grid, towerCoverGrid, gridSize: Vector2i = Vector2i(1, 1)):
	# 兜底：本关不放行的塔一律拒绝（tower_ui 已经把卡片置灰，这里防止绕过）
	if not Game.endlessMode and not StageData.isTowerAllowed(StageData.currentStageId, type):
		addNotice(tr("_TowerLockedInStage"))
		return
	if titleNode.money < cost:
		# print('Insufficient funds')
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
	elif type == Game.towerType.ironBox:
		temp = ironBox.instantiate()
	else:
		push_error("未知塔类型: " + str(type))
		return
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
	var topLeft: Vector2i = grid - half
	var blockSize: Vector2i = Vector2i(gridSize.x * cellSize, gridSize.y * cellSize)
	temp.position = Vector2(topLeft * cellSize) + Vector2(blockSize * 0.5)
	temp.coverGrid = towerCoverGrid
	level.addOccupiedArea(towerCoverGrid)
	add_child(temp)
	# 记录本局用过的塔类型（全域火力成就）
	if achievementTracker:
		achievementTracker.recordTowerBuilt(type)
	#level.setShadowHide()
	
		
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
	# syncWaveProgressBar()

func onEnemyDefeated(point):
	titleNode.money += point


## 击败特殊敌人掉落宝石：入账 + 立刻落盘，再复用"宝石变化"那条现成链路
## （AbilityManager.gemChanged → onGemChanged）刷新顶栏数字与技能条可购买状态。
## 掉落数量由 enemyInfo.gemReward 决定（1 或 2），普通敌人根本不发这个信号。
func onGemRewarded(amount: int) -> void:
	UserData.addGem(amount)
	AbilityManager.gemChanged.emit(UserData.gem)
	# 青色提示，和关卡情报里的"宝石奖励"用同一个色，玩家一眼能认出是宝石
	addNotice(tr("_GemPicked") % amount, Color(0.4, 0.9, 1.0))

func onEnemyEscaped(point):
	# 逃脱敲钟：一声低沉的锣，提示玩家漏怪了。
	# 放在这里而不是各个敌人脚本里 —— 所有敌人（敌坦/直升机/维修车/导弹车…）
	# 都是发 Game.enemyEscape 信号，map 是唯一接收方，改一处就全覆盖。
	# 用 play 不用 play_at：敌人逃脱的位置就在基地（屏幕固定处），没必要做 2D 定位。
	# 加音高抖动是因为一波漏好几个时会连着响，同一声会糊成一片。
	SoundManage.play("enemy_escape_b", -4.0, randf_range(0.94, 1.06))
	# 先扣血再判定：hp 归零（而不是变成负数）就算基地被打爆
	titleNode.hp = maxi(0, titleNode.hp - point)
	if titleNode.hp <= 0:
		onDefenseFailed()

## 无尽结算：记录最高波数（击杀数 / 用时留到 M3 补）。
## ⚠️ 这里**不**碰 stageRatings / 关卡解锁 / 关卡通关成就 —— 无尽与关卡系统解耦。
func recordEndlessResult() -> void:
	var reached: int = int(level.currWave) if level != null else 0
	var kills: int = int(level.kills) if level != null and "kills" in level else 0
	var seconds: int = int(level.elapsedSeconds()) if level != null and level.has_method("elapsedSeconds") else 0
	UserData.endlessRuns += 1
	if reached > UserData.endlessBestWave:
		UserData.endlessBestWave = reached
		UserData.endlessBestKills = kills
	UserData.savePlayerData()
	# 无尽成就：按"撑到第几波"推进（目标值在 achievement_manager 里）
	AchievementManager.setProgress("endless_10", reached, false)
	AchievementManager.setProgress("endless_30", reached, false)
	AchievementManager.savePlayerAchievements()
	var minutes: int = int(floor(float(seconds) / 60.0))
	endlessStatsText = "%s · %s %d · %s %d:%02d" % [tr("_EndlessResult") % reached,
		tr("_EndlessKills"), kills, tr("_EndlessTime"), minutes, seconds % 60]
	addNotice(endlessStatsText, Color(1.0, 0.85, 0.4))


# 基地被打爆：直接进入失败结算
# 这里刻意不调用 pauseGame()，否则暂停菜单会和结算窗叠在一起
func onDefenseFailed() -> void:
	if resultScreen.visible:
		return
	get_tree().paused = true
	# 失败结算不会再走 finish()，把复查器关掉，避免它继续空转
	finishChecking = false
	finishTimer.stop()
	# 无尽模式：结算前把最高记录落盘（无尽没有"通关"，只有活到第几波）
	if Game.endlessMode:
		recordEndlessResult()
	resultScreen.setResult(true)
	# ⚠️ 必须在 setResult() 之后：它自己也会写 waveLabel
	if Game.endlessMode and not endlessStatsText.is_empty():
		resultScreen.waveLabel.text = endlessStatsText
	resultScreen.levelRating.rating = 0
	# ★ 这里**不要**再调 setGemReward —— setResult(true) 已经把宝石行隐藏了，
	#   而现在 setGemReward 是"通关时始终显示"，再调一次会把整行又亮出来。
	resultScreen.show()

func startGame():
	get_tree().paused = false
	# 顶栏 ▶/⏸ 同步成「正在运行」（= 显示暂停图，点一下才暂停）
	titleNode.setPlaying(true)
	# 玩家已经开打了，闪烁提示可以收了
	titleNode.stopPrompt()
	# 只有「本关第一次开打」才闪横幅；暂停后继续不再闪
	if not battleStarted:
		battleStarted = true
		# 玩家第一次点「开始」时起背景音乐。之后暂停再继续不会重头开始
		# （play_bgm 内部按曲名去重，同一首已在播就直接返回）。
		# ★ 08（bgm_08_lunar_amb）先不播，留着备用。
		SoundManage.playBgm("bgm_07_heaven_pad", -5.0)
		# 敌人来袭警报：整局只响这一次（暂停后继续不会再响）
		SoundManage.play("enemy_incoming", -2.0)
		if battleStartBanner != null:
			await battleStartBanner.play()
	level.start()
	# syncWaveProgressBar()

## 无尽模式的「结束本局」：主动认输，走和基地被打爆**完全一样**的结算
## （包括最高记录落盘与无尽成就），只是不用等基地真的没血。
func onEndlessGiveUp() -> void:
	pauseMenu.hide()
	get_tree().paused = false
	onDefenseFailed()


func pauseGame():
	get_tree().paused = true
	titleNode.setPlaying(false)
	if not pauseMenu.visible:
		# 「结束本局」只在无尽模式出现
		pauseMenu.showGiveUp(Game.endlessMode)
		pauseMenu.show()

func resumeGame():
	pauseMenu.hide()
	get_tree().paused = false
	titleNode.setPlaying(true)

func onSoundOnPressed():
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Sfx"), false)
	UserData.sfxMuted = false
	UserData.saveSettings()
	
func onSoundOffPressed():
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Sfx"), true)
	UserData.sfxMuted = true
	UserData.saveSettings()
	
func onMusicOnPressed():
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Bg"), false)
	UserData.musicMuted = false
	UserData.saveSettings()
	
func onMusicOffPressed():
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Bg"), true)
	UserData.musicMuted = true
	UserData.saveSettings()

func onHomePressed():
	pauseGame()

func onSpeedOnPressed():
	pass
	
func onSpeedOffPressed():
	pass

# 出售防御塔
func onTowerSold(money, coverGrid: Array[Vector2i]):
	level.removeOccupiedArea(coverGrid)
	titleNode.money += money


## 塔被打爆：只归还格子，**不给钱**（给钱是"出售"才有的收益）。
## 顺便把右侧信息面板收起来 —— 用 clear() 而不是 hide()，它还会把 tower 引用置空，
## 免得面板继续指着一座已经被 free 的塔。
func onTowerGridReleased(coverGrid: Array[Vector2i]) -> void:
	if level != null:
		level.removeOccupiedArea(coverGrid)
	if towerDetailPanel != null:
		towerDetailPanel.clear()

# 修理防御塔：扣费成功后把血量回满
func onTowerRepaired(cost: int, tower: Node) -> void:
	if not is_instance_valid(tower):
		return
	if titleNode.money < cost:
		addNotice(tr("_NotEnoughMoney"))
		return
	titleNode.money -= cost
	tower.applyRepair()
	if towerDetailPanel:
		towerDetailPanel.refresh()

## 最后一波**开始生成**时触发（注意：不是"打完了"）。
## 这里只负责把结算复查器打开 —— 真正的结束判定在 finish() 里反复复查，
## 直到「生产列表空 + 场上无敌人」才弹结算。
func onLastWaveStarted():
	# 已经结算过就不再重新开启复查（重复的 lastWaveStarted 会让结算面板反复弹）
	if settled:
		return
	isLastWave = true
	finishChecking = true
	finishTimer.start()

## 结算复查（周期触发，见 map.tscn 的 Timer：wait_time=0.5, one_shot=false）
##
## ⚠️ 旧实现的两个坑（2026-09-26 修）：
##   ① Timer 是 one_shot=true + wait_time=2.0 —— 只查一次。
##      如果那一次恰好敌人还没清完，就直接 return 且**再也不会复查**，永远不结算。
##   ② lastWave 是在最后一波"刚加入生产列表"时发出的，那一刻敌人一个都还没生成，
##      只靠一次判定很容易在敌人全灭前/后错拍。
## 现在改成 0.5 秒复查一次，条件满足才结算，满足后停表。
func finish():
	if not finishChecking:
		return
	if level == null:
		return
	# 敌人还在生产队列里 → 继续等
	if level.currentSpawner.size() > 0:
		return
	# 场上还有活着的敌人 → 继续等
	if get_tree().get_nodes_in_group("enemy").size() > 0:
		return

	# 到这里才算真的"全部清空"，停止复查
	finishChecking = false
	finishTimer.stop()

	# 结算只做一次：重复触发时第二次起直接返回，
	# 否则宝石行会被 0 覆盖、通关分数与成就被重复累加。
	if settled:
		return
	settled = true

	# 记录最高评分、奖励和下一关解锁状态
	var rating = calculateStars()
	# rating 为 0 表示基地已经被打爆，不算通关：不写星级、不解锁关卡、不发宝石
	# （失败结算已经在 _on_defense_failed() 里弹过了，这里直接结束）
	if rating <= 0:
		return
	recordAchievements(rating)
	var gemReward: int = UserData.recordStageCompletion(StageData.currentStageId, rating)
	titleNode.score = UserData.score
	resultScreen.setResult(false)
	resultScreen.levelRating.rating = rating
	resultScreen.setGemReward(gemReward)
	resultScreen.show()

# 根据基地剩余生命计算三档星级
func calculateStars() -> int:
	if titleNode.hp <= 0:
		return 0
	var healthRatio: float = float(titleNode.hp) / float(level.health)
	if healthRatio >= 1.0:
		return 3
	if healthRatio >= 0.5:
		return 2
	return 1

# 通关结算时提交成就进度
# rating 为 0 表示基地被打爆，不算通关，不记录任何通关类成就
func recordAchievements(rating: int) -> void:
	if achievementTracker == null or rating <= 0:
		return
	# 基地全程没掉血 <=> 没有任何敌人逃脱
	var flawless: bool = titleNode.hp >= level.health
	achievementTracker.recordStageCleared(StageData.currentStageId, flawless, isMultiRouteLevel())

# 关卡是否有多条行军路线（存在多条 Path2D）
func isMultiRouteLevel() -> bool:
	if level == null:
		return false
	var pathCount: int = 0
	for child in level.get_children():
		if child is Path2D:
			pathCount += 1
			if pathCount > 1:
				return true
	return false

## 统一通过提示组件显示短时通知，避免各处重复管理提示节点。
func addNotice(s, color: Color = Color.CORAL):
	toastInfo.display(s, color)

# 玩家点了本关禁用的塔卡片
func onTowerLocked() -> void:
	addNotice(tr("_TowerLockedInStage"))

## 塔与敌人共用右侧详情栏，因此这里负责保持单选并更新面板。
func onTowerClicked(item, selected):
	# 点地图上已放置的塔：给一声"选中"反馈。
	# 和工具箱里点塔卡片用的是同一个音，但音高略低一点，
	# 耳朵能分出是"在地图上选的"还是"在工具箱里选的"。
	if selected:
		SoundManage.play("tower_select", 0.0, 0.94)
		# 右侧信息面板同一时间只服务一个目标：选中塔时收起敌人面板
		clearEnemyDetail()
		# 保持同一时间只选中一座塔，先取消之前选中的
		if selectedTower != null and selectedTower != item and is_instance_valid(selectedTower):
			var oldTower = selectedTower
			selectedTower = null # 先清空，避免 hideSelect 触发的回调把状态弄乱
			oldTower.hideSelect()
		selectedTower = item
		if towerDetailPanel:
			towerDetailPanel.showTower(item)
	else:
		if selectedTower == item:
			selectedTower = null
		if towerDetailPanel:
			towerDetailPanel.clear()

## 敌人与塔共用右侧详情栏，选中敌人前必须先取消塔的选择状态。
func onEnemyClicked(enemy):
	if enemy == null or not is_instance_valid(enemy):
		return
	enemyClickMsec = Time.get_ticks_msec()
	# 再次点击同一个敌人 -> 取消选中
	if enemyDetailPanel and enemyDetailPanel.visible and enemyDetailPanel.enemy == enemy:
		enemyDetailPanel.clear()
		return
	deselectTower()
	if enemyDetailPanel:
		enemyDetailPanel.showEnemy(enemy)

# 收起敌人信息面板
func clearEnemyDetail():
	if enemyDetailPanel:
		enemyDetailPanel.clear()

# 取消当前选中的塔（不递归触发敌人选中）
func deselectTower():
	if selectedTower != null and is_instance_valid(selectedTower):
		var oldTower = selectedTower
		selectedTower = null # 先清空，避免 hideSelect 触发的回调把状态弄乱
		oldTower.hideSelect()

func restart():
	get_tree().paused = false
	get_tree().reload_current_scene.call_deferred()

func nextLevel():
	SceneTransition.changeScene("res://scene/level_select.tscn")

func returnHome():
	# 离开无尽模式：清掉标记，避免下一局/下一关被当成无尽
	Game.endlessMode = false
	get_tree().paused = false
	SceneTransition.changeScene("res://scene/welcome.tscn")

func onAbilitySelectionChanged(_ability_id: String) -> void:
	queue_redraw()


## 技能花掉宝石：把顶栏的宝石数字同步成最新值。
func onGemChanged(_gem: int) -> void:
	if titleNode != null:
		titleNode.gem = UserData.gem
	# 宝石数变了，技能槽可不可用也可能变，让技能条刷新一次
	if abilityBar != null and abilityBar.has_method("refreshAffordable"):
		abilityBar.refreshAffordable()


## 技能没放出来。目前只有"宝石不够"这一种需要提示玩家。
func onAbilityFailed(_ability_id: String, reason: String) -> void:
	if reason == "no_gem":
		addNotice(tr("_NotEnoughGem"))
	

func confirmAbilityTarget() -> void:
	AbilityManager.confirmTarget(get_global_mouse_position())


# 收集范围内自己的防御塔（塔直接挂在 map 下）
func getTowersInRadius(center: Vector2, radius: float) -> Array[Tower]:
	var result: Array[Tower] = []
	for child in get_children():
		if not (child is Tower) or not is_instance_valid(child):
			continue
		if (child as Tower).global_position.distance_to(center) <= radius:
			result.append(child)
	return result


## 轰炸技能的专属爆炸演出（比普通爆炸大一圈 + 有扩散烟，见 script/fx/bombard_strike.gd）
const BOMBARD_STRIKE := preload("res://scene/fx/bombard_strike.tscn")


# 区域轰炸：对范围内所有敌人造成伤害，并用提示反馈命中数量
func areaDamage(center: Vector2, radius: float, damage: int) -> bool:
	if radius <= 0.0 or damage <= 0:
		return false
	var hitCount: int = 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(center) > radius:
			continue
		if enemy.has_method("hurt"):
			enemy.hurt(damage, null, "energy")
			hitCount += 1
	ExplosionManage.playExplosion(center)
	playBombardStrike(center, radius)
	if hitCount > 0:
		addNotice(Game.t("_ability_bombard_hit", "Airstrike hit %d enemies") % hitCount, Color(1.0, 0.776, 0.102))
		return true
	# ⚠️ 这里必须返回 false：技能现在要花宝石，而 AbilityManager 只有拿到 true 才扣。
	#    如果没打中也返回 true，玩家会**白丢一颗宝石**（以前不花宝石时返回啥都无所谓）。
	addNotice(Game.t("_ability_bombard_miss", "Airstrike hit nothing"), Color(0.86, 0.92, 0.95))
	return false


## 轰炸技能的专属爆炸演出（比普通爆炸大一圈 + 带一圈往外扩散的烟）。
## 普通的子弹/塔爆炸仍然走 ExplosionManage，这里只给技能用。
func playBombardStrike(center: Vector2, radius: float) -> void:
	var strike: Node2D = BOMBARD_STRIKE.instantiate()
	strike.position = center
	add_child(strike)
	strike.play(radius)


# 塔无敌：让范围内所有防御塔在一段时间内免疫伤害
func areaInvincible(center: Vector2, radius: float, duration: float) -> bool:
	if radius <= 0.0 or duration <= 0.0:
		return false
	var towers: Array[Tower] = getTowersInRadius(center, radius)
	for tower in towers:
		tower.setInvincible(duration)
	if towers.is_empty():
		# 同上：范围内没有塔就不算生效，不扣宝石、不进冷却
		addNotice(Game.t("_ability_invincible_miss", "No tower in range"), Color(0.86, 0.92, 0.95))
		return false
	addNotice(Game.t("_ability_invincible_hit", "%d towers are now invincible") % towers.size(), Color(1.0, 0.776, 0.102))
	return true


func onButtonPressed():
	# 地图内按钮用 ui_confirm（区别于菜单里的 coin）
	SoundManage.playConfirm()
	resultScreen.show()
	
	pass # Replace with function body.


func _physics_process(_delta: float) -> void:
	# 选择技能目标时也要重绘，让范围预览跟着鼠标走
	if debug or AbilityManager.isSelectingPosition():
		queue_redraw()


# 技能选中 / 取消都要重绘一次。
# ⚠️ 取消时如果不重绘，_physics_process 里的条件变假 → 再也不调 _draw，
#    最后一帧画的范围预览圈就会一直留在画布上（黄色的圈不消失）。


func _unhandled_input(_event):
	# 正在等待技能目标时，这一击只用于确认/取消技能，不再走原来的取消逻辑
	if AbilityManager.isSelecting():
		if _event.is_action_pressed("click"):
			confirmAbilityTarget()
			return
		if _event.is_action_pressed("selectCancel"):
			AbilityManager.cancelSelecting()
			return
	if _event.is_action_pressed("selectCancel"):
		for i in get_tree().get_nodes_in_group("placeableArea"):
			i.isShow = false
		#towerShadow.setInactive()
	if _event.is_action_pressed("click"):
		# 这一击若刚选中了敌人，就不要再当成“点空地”把面板取消掉
		if Time.get_ticks_msec() - enemyClickMsec > 150:
			clearEnemyDetail()
		if selectedTower and is_instance_valid(selectedTower):
			selectedTower.hideSelect()


# 确认技能目标：范围类技能直接用鼠标位置


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
	if AbilityManager.isSelectingPosition():
		var radius: float = AbilityManager.getSelectingRadius()
		if radius > 0.0:
			var mousePos: Vector2 = get_local_mouse_position()
			var circleColor: Color = Color(1.0, 0.776, 0.102, 1.0)
			draw_circle(mousePos, radius, Color(circleColor.r, circleColor.g, circleColor.b, 0.16))
			draw_arc(mousePos, radius, 0.0, TAU, 64, Color(circleColor.r, circleColor.g, circleColor.b, 0.9), 3.0)


## 离开战斗场景时停掉背景音乐。
##
## ★ 为什么必须在这里停：SoundManage 是 **autoload**（跨场景常驻），
##   它持有的 Bgm 播放器不会因为地图场景被释放而停止。而开战时
##   `startGame()` 会 `playBgm("bgm_07_heaven_pad")`，全项目**没有任何地方**
##   调用 `stopBgm()` —— 于是从战斗返回欢迎界面 / 结算返回主菜单之后，
##   战斗 BGM 会一直响下去。
##
##   放在 `_exit_tree()` 而不是各个返回按钮里：返回主菜单 / 下一关 / 重开本关
##   都走 `SceneTransition.changeScene()`，地图场景都会被释放，这一个钩子
##   就能覆盖全部出口，不用在每个按钮回调里重复写一遍、也不会漏。
func _exit_tree() -> void:
	SoundManage.stopBgm()
	# 工具箱提示的 tween 挂在 tower_ui 上，场景一起走，这里不必额外清理；
	# 但把待办标记复位，避免同一实例被复用（reload_current_scene）时残留。
	pendingToolboxHint = false
