extends Control
## 通用技能槽（所有技能共用这个场景）
##
## 只负责单个技能图标的显示与交互：
##   - 图标（素材来自 AbilityManager，可替换）
##   - 槽内 Timer 计时作为冷却时间（冷却的唯一来源）
##   - 冷却遮罩用 shader/ability_cooldown.gdshader 做扇形扫描
##   - 剩余秒数
##
## 技能条通过 setup() 传入技能 id，并监听三个信号与技能管理器对接。

signal slot_clicked(ability_id: String)
signal slot_hovered(ability_id: String, slot: Control)
signal slot_unhovered

# 槽背景：常态 / 高亮（正在等待选择目标）
const STYLE_NORMAL := preload("res://theme/style/btn_normal.tres")
const STYLE_ACTIVE := preload("res://theme/style/btn_hover.tres")

const COLOR_READY := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_COOLING := Color(0.72, 0.76, 0.80, 1.0)

@onready var bg: Panel = $bg
@onready var icon: TextureRect = $icon
@onready var cooldown_rect: ColorRect = $cooldown
@onready var cooldown_label: Label = $cooldownLabel
@onready var cooldown_timer: Timer = $Timer

var ability_id: String = ""


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	# 没有冷却时不需要逐帧刷新
	set_process(false)


# 绑定技能 id 并初始化显示
func setup(id: String) -> void:
	ability_id = id
	icon.texture = AbilityManager.get_icon(id)
	cooldown_timer.stop()
	cooldown_timer.wait_time = maxf(AbilityManager.get_cooldown_total(id), 0.1)
	set_highlighted(false)
	_refresh(0.0)


# 冷却是否进行中
func is_cooling() -> bool:
	return cooldown_timer.time_left > 0.0


# 开始冷却（技能确认生效后由技能条调用）
func start_cooldown() -> void:
	if cooldown_timer.wait_time <= 0.0:
		return
	cooldown_timer.start()
	_refresh(1.0)
	set_process(true)


# 高亮开关（等待选择目标时点亮）
func set_highlighted(on: bool) -> void:
	bg.add_theme_stylebox_override("panel", STYLE_ACTIVE if on else STYLE_NORMAL)


func _process(_delta: float) -> void:
	var total := cooldown_timer.wait_time
	if total <= 0.0:
		set_process(false)
		return
	_refresh(cooldown_timer.time_left / total)


func _on_cooldown_timeout() -> void:
	_refresh(0.0)
	set_process(false)


# 更新冷却遮罩（着色器 progress）与剩余秒数
func _refresh(ratio: float) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	var mat := cooldown_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("progress", clamped)
	cooldown_rect.visible = clamped > 0.001

	var left := cooldown_timer.time_left
	cooldown_label.visible = left > 0.0
	if left > 0.0:
		cooldown_label.text = str(int(ceil(left)))

	modulate = COLOR_READY if clamped <= 0.001 else COLOR_COOLING


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(ability_id)
		accept_event()


func _on_mouse_entered() -> void:
	slot_hovered.emit(ability_id, self)


func _on_mouse_exited() -> void:
	slot_unhovered.emit()
