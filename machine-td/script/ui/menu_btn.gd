extends PanelContainer

## 地图顶栏按钮（▶/⏸ 播放暂停、音乐、静音、返回主菜单）。
##
## 点击音**由按钮自己播**，和 ui_button.tscn 是同一个约定：
## 场景脚本不要再为这些按钮补 SoundManage.playXxx()，否则会响两声。
##
## 注意里面那个 TextureButton 有的是 toggle_mode（▶/⏸、音乐、静音），
## 有的是普通按钮（返回），所以两种信号都要接，且各自只接一次。

@onready var _btn: BaseButton = $MarginContainer/btnStart


func _ready() -> void:
	if _btn == null:
		return
	if _btn.toggle_mode:
		_btn.toggled.connect(_on_toggled)
	else:
		_btn.pressed.connect(_on_pressed)


func _on_toggled(_pressed: bool) -> void:
	SoundManage.playConfirm()


func _on_pressed() -> void:
	SoundManage.playConfirm()
