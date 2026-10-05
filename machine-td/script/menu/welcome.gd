extends Node2D

@onready var aboutPanel = $AboutPanel
@onready var settingPanel = $setting
@onready var achievementIcon: TextureButton = $Ui/achievement
@onready var achievementPanel = $AchievementPanel
@onready var codexPanel = $CodexPanel

var _glowTween: Tween


func _ready() -> void:
	# 回到主菜单＝已经离开无尽模式（从无尽里点返回也走这条路）
	Game.endlessMode = false
	var sfxBus: int = AudioServer.get_bus_index("Sfx")
	if sfxBus >= 0:
		AudioServer.set_bus_mute(sfxBus, UserData.sfxMuted)

	if achievementPanel:
		achievementPanel.visible = false
		achievementPanel.closed.connect(_onAchievementPanelClosed)
	if achievementIcon:
		achievementIcon.mouse_entered.connect(_onAchievementIconMouseEntered)
		achievementIcon.mouse_exited.connect(_onAchievementIconMouseExited)
		achievementIcon.pressed.connect(_onAchievementIconPressed)
		_setAchievementGlow(0.0)


func _onButton3Pressed():
	aboutPanel.show()


# 单位图鉴（敌人 / 防御塔资料）—— 按钮在"关于"上方
# 面板自己管显示（场景里就是 visible = false，close() 里自己隐藏），这里只管打开
func _onCodexPressed() -> void:
	codexPanel.open()


func _onTutorialPressed() -> void:
	StageData.currentStageId = 0
	SceneTransition.changeScene("res://scene/map.tscn")

# 无尽模式：置标记后直接进 map 外壳，由它加载 scene/level/endless.tscn
# （不经过关卡选择，也不读 allStage）
func _onEndlessPressed() -> void:
	Game.endlessMode = true
	SceneTransition.changeScene("res://scene/map.tscn")



func _onBtnSStartPressed() -> void:
	#var map=load("res://scene/map.tscn")
	#get_tree().change_scene_to_packed(map)
	#get_tree().change_scene_to_file("res://scene/level_select.tscn")
	SceneTransition.changeScene("res://scene/level_select.tscn")

func _onSettingPressed() -> void:
	settingPanel.show()


func _onSettingClose() -> void:
	settingPanel.hide()


# ---------- 成就图标：悬停时轮廓发光 ----------

func _onAchievementIconMouseEntered() -> void:
	_tweenAchievementGlow(1.0)


func _onAchievementIconMouseExited() -> void:
	_tweenAchievementGlow(0.0)


func _onAchievementIconPressed() -> void:
	SoundManage.playEffect()
	if achievementPanel:
		achievementPanel.open()


func _onAchievementPanelClosed() -> void:
	if achievementPanel:
		achievementPanel.visible = false


# 把着色器的 glow 参数补间到目标值（0=不发光，1=满强度）
func _tweenAchievementGlow(target: float) -> void:
	var mat: ShaderMaterial = _achievementMaterial()
	if mat == null:
		return
	if _glowTween != null and _glowTween.is_valid():
		_glowTween.kill()
	var from: float = float(mat.get_shader_parameter("glow"))
	_glowTween = create_tween()
	_glowTween.tween_method(_setAchievementGlow, from, target, 0.18)


func _setAchievementGlow(value: float) -> void:
	var mat: ShaderMaterial = _achievementMaterial()
	if mat != null:
		mat.set_shader_parameter("glow", value)


func _achievementMaterial() -> ShaderMaterial:
	if achievementIcon == null or not is_instance_valid(achievementIcon):
		return null
	return achievementIcon.material as ShaderMaterial
