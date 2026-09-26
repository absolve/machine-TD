extends VBoxContainer

## 音量条组件。静音后会把对应音频总线整体静音，
## 并用图标和置灰的滑条提示“此时调节音量不会生效”。
signal muteToggled(isMuted: bool)

@export var busName = 'Master':
	set(val):
		#busNameLabel.text=str(val)
		sound.bus = val
		busName = val
		_applyMute()
		
@export var volume: float = 0.0:
	set(val):
		volume = val
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(busName), linear_to_db(volume))

## 是否在滑条右侧显示静音按钮。
@export var showMuteButton: bool = false:
	set(val):
		showMuteButton = val
		_refreshMuteButtonVisible()
		_refreshMuteVisual()

## 当前是否处于静音状态。
@export var muted: bool = false:
	set(val):
		muted = val
		_refreshMuteVisual()
		_applyMute()

## 静音按钮的图标：未静音 / 已静音。
@export var muteIconOn: Texture2D = null:
	set(val):
		muteIconOn = val
		_refreshMuteVisual()

@export var muteIconOff: Texture2D = null:
	set(val):
		muteIconOff = val
		_refreshMuteVisual()


@onready var busNameLabel = $name
@onready var sound = $sound
@onready var slider: HSlider = $volumeRow/HSlider
@onready var btnMute: TextureButton = get_node_or_null("volumeRow/btnMute")


func _ready() -> void:
	if btnMute:
		btnMute.set_pressed_no_signal(muted)
		btnMute.toggled.connect(_on_btn_mute_toggled)
	_refreshMuteButtonVisible()
	_refreshMuteVisual()
	_applyMute()


func _refreshMuteButtonVisible() -> void:
	if not is_node_ready() or btnMute == null:
		return
	btnMute.visible = showMuteButton


func _refreshMuteVisual() -> void:
	if not is_node_ready():
		return
	if btnMute:
		btnMute.set_pressed_no_signal(muted)
		if muteIconOn:
			btnMute.texture_normal = muteIconOn
		if muteIconOff:
			btnMute.texture_pressed = muteIconOff
	if slider and showMuteButton:
		# 静音时把滑条置灰，提示此时调音量没有实际效果
		slider.modulate = Color(1, 1, 1, 0.4) if muted else Color(1, 1, 1, 1)


func _applyMute() -> void:
	if not is_node_ready():
		return
	# 没有静音按钮的音量条不接管总线静音，避免影响别处的静音设置
	if not showMuteButton and not muted:
		return
	var bus_index := AudioServer.get_bus_index(busName)
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, muted)


func _on_btn_mute_toggled(toggled_on: bool) -> void:
	muted = toggled_on
	muteToggled.emit(muted)


func playSound():
	if sound.stream:
		sound.play()

func setVolume(value: int) -> void:
	slider.value = value
	volume = value / 100.0
