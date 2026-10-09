extends Control
## 战斗内技能条（显示在地图左侧）
##
## 只负责：按关卡配置实例化通用技能槽、悬停说明、把技能槽与技能管理器接起来。
## 单个技能图标的显示、冷却计时、冷却遮罩全在 ability_slot.tscn 里，
## 所以新增技能只需要在 AbilityManager.ABILITIES 加一条配置，不用改这个脚本。
## 本关启用的技能由 map 通过 setup() 传入（来自 StageData.stageAbilities 配置）。

const SLOT_SCENE := preload("res://scene/ability_slot.tscn")
const TOOLTIP_OFFSET_X := 18.0 # 说明面板与技能槽的间距

@onready var slots: VBoxContainer = $Slots
@onready var tooltipPanel: PanelContainer = $TooltipPanel
@onready var nameLabel: Label = $TooltipPanel/margin/vbox/nameLabel
@onready var descLabel: Label = $TooltipPanel/margin/vbox/descLabel
@onready var infoLabel: Label = $TooltipPanel/margin/vbox/infoLabel

# ability_id -> 技能槽节点（ability_slot.tscn 实例）
var slotNodes: Dictionary = {}


func _ready() -> void:
	tooltipPanel.visible = false
	AbilityManager.selectionStarted.connect(onSelectionChanged)
	AbilityManager.selectionEnded.connect(onSelectionChanged)
	AbilityManager.abilityActivated.connect(onAbilityActivated)


# 由 map 调用：按本关配置重建技能槽
func setup(abilityIds: Array) -> void:
	clearSlots()
	for id in abilityIds:
		var key: String = str(id)
		var slot: Node = SLOT_SCENE.instantiate()
		slots.add_child(slot)
		slot.setup(key)
		slot.slotClicked.connect(onSlotClicked)
		slot.slotHovered.connect(onSlotHovered)
		slot.slotUnhovered.connect(onSlotUnhovered)
		slotNodes[key] = slot
	visible = not slotNodes.is_empty()


# ===== 技能槽交互 =====
func onSlotClicked(abilityId: String) -> void:
	var slot: Control = slotNodes.get(abilityId)
	# 冷却中直接拦下（冷却时间以技能槽内的 Timer 为准）
	if slot and slot.isCooling():
		return
	# 宝石不够也拦下 —— AbilityManager 里还会再判一次（那边才是权威），
	# 这里拦是为了不发多余的选择状态。提示统一由 map 接 ability_failed 弹。
	if not AbilityManager.canAfford(abilityId):
		return
	AbilityManager.tryActivate(abilityId)


## 宝石数量变化后刷新所有槽的"买不买得起"状态。
## 由 map 接 AbilityManager.gem_changed 时调用。
func refreshAffordable() -> void:
	for id in slotNodes.keys():
		var slot: Control = slotNodes[id]
		if slot.has_method("refreshAffordable"):
			slot.refreshAffordable()


func onSlotHovered(abilityId: String, slot: Control) -> void:
	showTooltip(abilityId, slot)


func onSlotUnhovered() -> void:
	tooltipPanel.visible = false


# ===== 与技能管理器联动 =====
# 技能确认生效后，让对应的技能槽开始冷却
func onAbilityActivated(abilityId: String, _target) -> void:
	var slot: Control = slotNodes.get(abilityId)
	if slot:
		slot.startCooldown()


func onSelectionChanged(_ability_id: String) -> void:
	var selecting: String = AbilityManager.getSelectingId()
	for id in slotNodes.keys():
		var slot: Control = slotNodes[id]
		slot.setHighlighted(id == selecting)
	# 选择目标时收起说明，避免挡住地图
	if not selecting.is_empty():
		tooltipPanel.visible = false
		# 技能被选中、进入"点地图选目标"状态 —— 给一声科技感的确认音。
		# 放在这里而不是 _on_slot_clicked：那个函数对"瞬发技能"也会走，
		# 而这里只在真的进入选择状态时才响（selection_started 触发）。
		SoundManage.play("ability_select")


# ===== 悬停说明 =====
func showTooltip(abilityId: String, slot: Control) -> void:
	nameLabel.text = AbilityManager.getDisplayName(abilityId)
	descLabel.text = AbilityManager.getDescription(abilityId)

	var data: Dictionary = AbilityManager.getDefinition(abilityId)
	var parts: Array[String] = []
	var target_type: int = int(data.get("target_type", AbilityManager.TargetType.NONE))
	if target_type == AbilityManager.TargetType.POSITION:
		parts.append(Game.t("_ability_target_position", "Click the map to choose an area."))
	# 宝石成本放最前面 —— 这是现在最关键的资源限制
	var cost: int = AbilityManager.getGemCost(abilityId)
	if cost > 0:
		var costText: String = Game.t("_ability_gem_cost_fmt", "Cost: %d gem") % cost
		if not AbilityManager.canAfford(abilityId):
			costText += "  " + Game.t("_ability_gem_lack", "(not enough)")
		parts.append(costText)
	parts.append(Game.t("_ability_cooldown_fmt", "Cooldown: %ss") % int(AbilityManager.getCooldownTotal(abilityId)))
	var effect: Dictionary = data.get("effect", {})
	if effect.has("duration"):
		parts.append(Game.t("_ability_duration_fmt", "Duration: %ss") % int(effect.get("duration", 0)))
	infoLabel.text = "\n".join(parts)

	tooltipPanel.visible = true
	tooltipPanel.reset_size()
	# 弹到技能槽右侧，纵向与技能槽对齐
	tooltipPanel.position = Vector2(slot.position.x + slot.size.x + TOOLTIP_OFFSET_X, slot.position.y)


# ===== 清理 =====
func clearSlots() -> void:
	for child in slots.get_children():
		slots.remove_child(child)
		child.queue_free()
	slotNodes.clear()
	tooltipPanel.visible = false
