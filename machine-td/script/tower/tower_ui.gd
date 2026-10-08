extends Control


@onready var info = $TowerInfo
@onready var towerCardList = $ScrollContainer/PanelContainer/vbox
@onready var player = $Player
@onready var toolboxIcon: TextureRect = $icon

var isOpen = false
var towerCard = preload("res://scene/tower_card.tscn")

# 工具箱图标两态：合着 = 关上的工具箱；打开 = 掀开盖子、里面一把锤子（由 _onIconGuiInput 切换）
var iconClosed = preload("res://sprite/icon/ui/redesigned/toolbox_closed.svg")
var iconOpen = preload("res://sprite/icon/ui/redesigned/toolbox_open.svg")


var tower1 = preload("res://sprite/tower/turret_machinegun.png")
var tower2 = preload("res://sprite/tower/turret_cannon.png")
var tower3 = preload("res://sprite/tower/turret_rocket.png")
var tower4 = preload("res://sprite/tower/turret_emp.png")
var tower5 = preload("res://sprite/tower/tower_tesla.png")
var tower6 = preload("res://sprite/tower/tower_laser.png")
var tower7 = preload("res://sprite/tower/tower_drone.png")
var tower8 = preload("res://sprite/tower/turret_ironbox.png")

var towerIcon = preload("res://scene/tower_icon.tscn")

var towersData = [
	{'type': Game.towerType.ironBox, 'img': tower8},
	{'type': Game.towerType.machineGunTower, 'img': tower1},
{'type': Game.towerType.cannonTower, 'img': tower2}, {'type': Game.towerType.rocketTower, 'img': tower3},
{'type': Game.towerType.EMPTower, 'img': tower4},
{'type': Game.towerType.teslaCoilTower, 'img': tower5},
{'type': Game.towerType.laserTower, 'img': tower6},
{'type': Game.towerType.droneBase, 'img': tower7},
]


func _ready() -> void:
	# 本关放行的塔；空数组 = 不限制（全部可建）
	var allowed: Array = StageData.getTowers(StageData.currentStageId)
	for i in towersData:
		var towerCard1 = towerCard.instantiate()
		towerCardList.add_child(towerCard1)
		towerCard1.setImg(i.img)
		towerCard1.type = i.type
		var temp = Game.towerInfo.get(i.type)
		towerCard1.setCost(temp.cost)
		# 卡片只显示图标 + 价格；塔名由详情面板展示
		# 本关不放行的塔：卡片变灰、点了只弹提示
		towerCard1.setLocked(not allowed.is_empty() and not (i.type in allowed))
		towerCard1.connect("clicked", towerClick)
		towerCard1.connect("lockedClicked", towerLockedClick)
		towerCard1.infoShown.connect(showTowerInfo)
		towerCard1.connect("mouse_exited", hideTowerInfo)


# 点了本关禁用的塔 → 交给 map 弹一句提示
func towerLockedClick(_type) -> void:
	Game.towerLocked.emit()
	
#func showInfo(_type):
	#var temp = Game.towerInfo.get(_type)
	#info.showDetail(temp)
	#info.global_position = get_global_mouse_position()
	#info.visible = true
	#
#func hideInfo(_type):
	#info.visible = false
#
#func itemSelect(_type):
	#Game.selectTower.emit(_type)


func showTowerInfo(type):
	var temp = Game.towerInfo.get(type)
	# 先移到屏幕外，避免在旧位置闪烁
	info.global_position = Vector2(-99999, -99999)
	info.showDetail(temp, type)
	# 等待一帧让布局更新，获取正确的尺寸
	await get_tree().process_frame
	var infoSize = info.size
	var mousePos = get_global_mouse_position()
	var viewportSize = get_viewport_rect().size
	# 默认显示在鼠标上方，水平居中对齐鼠标
	var targetPos = Vector2(
		mousePos.x - infoSize.x / 2.0,
		mousePos.y - infoSize.y
	)
	# 如果上方超出屏幕，则显示在鼠标下方
	if targetPos.y < 0:
		targetPos.y = mousePos.y
	# 限制在屏幕范围内
	targetPos.x = clamp(targetPos.x, 0, max(0, viewportSize.x - infoSize.x))
	targetPos.y = clamp(targetPos.y, 0, max(0, viewportSize.y - infoSize.y))
	info.global_position = targetPos
	

func hideTowerInfo():
	info.hideDetail()

func towerClick(type):
	# 在工具箱里点中一种塔 —— 用专门的选中音，和开合工具箱的机械音区分开
	# 音量已在素材里归一化过，这里不要再压（之前压了 -2dB 叠加素材本身偏轻，几乎听不见）
	SoundManage.play("tower_select")
	Game.selectTower.emit(type)


func _onIconGuiInput(_event):
	if Input.is_action_just_pressed("click"):
		isOpen = !isOpen
		# 图标跟着开合状态换（箱子状态一眼可见，不再靠“变淡”区分）
		toolboxIcon.texture = iconOpen if isOpen else iconClosed
		# 工具箱开 / 合各用一声专用机械音（比通用确认音更像"打开工具箱"）。
		# 开是闩锁咔哒、合是收回时略低一档，听得出方向。
		if isOpen:
			SoundManage.play("toolbox_click")
			player.play("show")
			# 玩家已经知道工具箱在哪了，新手提示可以收了
			stopToolboxPrompt()
		else:
			SoundManage.play("toolbox_take", 0.0, 0.92)
			player.play("hide")


## ── 工具箱的呼吸提示 ──
## 给「没玩教程关就直接进第 1 关」的玩家指路：让左上角工具箱图标一闪一闪，
## 直到他点开工具箱为止（见 map.gd::_startToolboxHint）。
##
## 手法和 title.gd::promptStart() 完全一致，包括下面那条 parallel() 的坑：
##   ⚠️ 只能用 parallel() 让「紧跟的那一条」并行。若写成 set_parallel(true)，
##      后面所有 tweener 都会并行 —— 变亮/变暗、放大/缩小同时跑，互相抵消，
##      scale 会永远停在 1.0（title.gd 那里已经踩过一次）。
var _toolboxPromptTween: Tween


func promptToolbox() -> void:
	stopToolboxPrompt()
	if toolboxIcon == null:
		return
	# 已经开着就不用提示了
	if isOpen:
		return
	toolboxIcon.pivot_offset = toolboxIcon.size * 0.5
	_toolboxPromptTween = create_tween().set_loops()
	_toolboxPromptTween.tween_property(toolboxIcon, "modulate",
		Color(1.9, 1.8, 1.25), 0.45).set_trans(Tween.TRANS_SINE)
	_toolboxPromptTween.parallel().tween_property(toolboxIcon, "scale",
		Vector2(1.18, 1.18), 0.45).set_trans(Tween.TRANS_SINE)
	_toolboxPromptTween.tween_property(toolboxIcon, "modulate",
		Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)
	_toolboxPromptTween.parallel().tween_property(toolboxIcon, "scale",
		Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)


func stopToolboxPrompt() -> void:
	if _toolboxPromptTween != null and _toolboxPromptTween.is_valid():
		_toolboxPromptTween.kill()
	_toolboxPromptTween = null
	if toolboxIcon != null:
		toolboxIcon.modulate = Color.WHITE
		toolboxIcon.scale = Vector2.ONE
