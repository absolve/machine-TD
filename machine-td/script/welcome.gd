extends Node2D

@onready var aboutPanel = $aboutPanel
@onready var settingPanel = $setting
@onready var achievementIcon: TextureButton = $ui/achievement
@onready var achievementPanel = $achievementPanel

var _glow_tween: Tween


func _ready() -> void:
	var sfx_bus := AudioServer.get_bus_index("Sfx")
	if sfx_bus >= 0:
		AudioServer.set_bus_mute(sfx_bus, UserData.sfxMuted)

	if achievementPanel:
		achievementPanel.visible = false
		achievementPanel.closed.connect(_on_achievement_panel_closed)
	if achievementIcon:
		achievementIcon.mouse_entered.connect(_on_achievement_icon_mouse_entered)
		achievementIcon.mouse_exited.connect(_on_achievement_icon_mouse_exited)
		achievementIcon.pressed.connect(_on_achievement_icon_pressed)
		_set_achievement_glow(0.0)


func _on_button_3_pressed():
	aboutPanel.popup_centered()


func _on_tutorial_pressed() -> void:
	StageData.currentStageId = 0
	SceneTransition.change_scene("res://scene/map.tscn")


func _on_btn_s_start_pressed() -> void:
	#var map=load("res://scene/map.tscn")
	#get_tree().change_scene_to_packed(map)
	#get_tree().change_scene_to_file("res://scene/level_select.tscn")
	SceneTransition.change_scene("res://scene/level_select.tscn")

func _on_setting_pressed() -> void:
	settingPanel.popup_centered()


func _on_setting_close() -> void:
	settingPanel.hide()


# ---------- 成就图标：悬停时轮廓发光 ----------

func _on_achievement_icon_mouse_entered() -> void:
	_tween_achievement_glow(1.0)


func _on_achievement_icon_mouse_exited() -> void:
	_tween_achievement_glow(0.0)


func _on_achievement_icon_pressed() -> void:
	SoundManage.playEffect()
	if achievementPanel:
		achievementPanel.open()


func _on_achievement_panel_closed() -> void:
	if achievementPanel:
		achievementPanel.visible = false


# 把着色器的 glow 参数补间到目标值（0=不发光，1=满强度）
func _tween_achievement_glow(target: float) -> void:
	var mat := _achievement_material()
	if mat == null:
		return
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	var from: float = float(mat.get_shader_parameter("glow"))
	_glow_tween = create_tween()
	_glow_tween.tween_method(_set_achievement_glow, from, target, 0.18)


func _set_achievement_glow(value: float) -> void:
	var mat := _achievement_material()
	if mat != null:
		mat.set_shader_parameter("glow", value)


func _achievement_material() -> ShaderMaterial:
	if achievementIcon == null or not is_instance_valid(achievementIcon):
		return null
	return achievementIcon.material as ShaderMaterial
