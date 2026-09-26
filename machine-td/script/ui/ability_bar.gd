extends Control
## 战斗内技能条（显示在地图左侧）
##
## 只负责：按关卡配置实例化通用技能槽、悬停说明、把技能槽与技能管理器接起来。
## 单个技能图标的显示、冷却计时、冷却遮罩全在 ability_slot.tscn 里，
## 所以新增技能只需要在 AbilityManager.ABILITIES 加一条配置，不用改这个脚本。
## 本关启用的技能由 map 通过 setup() 传入（来自 StageData.stageAbilities 配置）。

const SLOT_SCENE := preload("res://scene/ability_slot.tscn")
const TOOLTIP_OFFSET_X := 18.0 # 说明面板与技能槽的间距

@onready var slots: VBoxContainer = $slots
@onready var tooltip: PanelContainer = $tooltip
@onready var name_label: Label = $tooltip/margin/vbox/nameLabel
@onready var desc_label: Label = $tooltip/margin/vbox/descLabel
@onready var info_label: Label = $tooltip/margin/vbox/infoLabel

# ability_id -> 技能槽节点（ability_slot.tscn 实例）
var _slots: Dictionary = {}


func _ready() -> void:
	tooltip.visible = false
	AbilityManager.selection_started.connect(_on_selection_changed)
	AbilityManager.selection_ended.connect(_on_selection_changed)
	AbilityManager.ability_activated.connect(_on_ability_activated)


# 由 map 调用：按本关配置重建技能槽
func setup(ability_ids: Array) -> void:
	_clear_slots()
	for id in ability_ids:
		var key := str(id)
		var slot := SLOT_SCENE.instantiate()
		slots.add_child(slot)
		slot.setup(key)
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_hovered.connect(_on_slot_hovered)
		slot.slot_unhovered.connect(_on_slot_unhovered)
		_slots[key] = slot
	visible = not _slots.is_empty()


# ===== 技能槽交互 =====
func _on_slot_clicked(ability_id: String) -> void:
	var slot: Control = _slots.get(ability_id)
	# 冷却中直接拦下（冷却时间以技能槽内的 Timer 为准）
	if slot and slot.is_cooling():
		return
	AbilityManager.try_activate(ability_id)


func _on_slot_hovered(ability_id: String, slot: Control) -> void:
	_show_tooltip(ability_id, slot)


func _on_slot_unhovered() -> void:
	tooltip.visible = false


# ===== 与技能管理器联动 =====
# 技能确认生效后，让对应的技能槽开始冷却
func _on_ability_activated(ability_id: String, _target) -> void:
	var slot: Control = _slots.get(ability_id)
	if slot:
		slot.start_cooldown()


func _on_selection_changed(_ability_id: String) -> void:
	var selecting := AbilityManager.get_selecting_id()
	for id in _slots.keys():
		var slot: Control = _slots[id]
		slot.set_highlighted(id == selecting)
	# 选择目标时收起说明，避免挡住地图
	if not selecting.is_empty():
		tooltip.visible = false
		# 技能被选中、进入"点地图选目标"状态 —— 给一声科技感的确认音。
		# 放在这里而不是 _on_slot_clicked：那个函数对"瞬发技能"也会走，
		# 而这里只在真的进入选择状态时才响（selection_started 触发）。
		SoundManage.play("ability_select")


# ===== 悬停说明 =====
func _show_tooltip(ability_id: String, slot: Control) -> void:
	name_label.text = AbilityManager.get_display_name(ability_id)
	desc_label.text = AbilityManager.get_description(ability_id)

	var data := AbilityManager.get_definition(ability_id)
	var parts: Array[String] = []
	var target_type := int(data.get("target_type", AbilityManager.TargetType.NONE))
	if target_type == AbilityManager.TargetType.POSITION:
		parts.append(_t("_ability_target_position", "Click the map to choose an area."))
	parts.append(_t("_ability_cooldown_fmt", "Cooldown: %ss") % int(AbilityManager.get_cooldown_total(ability_id)))
	var effect: Dictionary = data.get("effect", {})
	if effect.has("duration"):
		parts.append(_t("_ability_duration_fmt", "Duration: %ss") % int(effect.get("duration", 0)))
	info_label.text = "\n".join(parts)

	tooltip.visible = true
	tooltip.reset_size()
	# 弹到技能槽右侧，纵向与技能槽对齐
	tooltip.position = Vector2(slot.position.x + slot.size.x + TOOLTIP_OFFSET_X, slot.position.y)


# ===== 清理 =====
func _clear_slots() -> void:
	for child in slots.get_children():
		slots.remove_child(child)
		child.queue_free()
	_slots.clear()
	tooltip.visible = false


# 取翻译；语言文件未导入该 key 时回退到默认英文文本
func _t(key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	var translated := tr(key)
	return fallback if translated == key else translated
