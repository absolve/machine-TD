extends Control

@onready var grid: GridContainer = $PanelContainer/VBoxContainer/ScrollContainer/GridContainer

func _ready() -> void:
	if AchievementManager:
		AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)
	refresh()

func _on_achievement_unlocked(_achievement_id: String, _achievement: Dictionary) -> void:
	refresh()

func refresh() -> void:
	for child in grid.get_children():
		child.queue_free()

	var achievement_map: Dictionary = AchievementManager.get_all_achievements()
	var ids: Array = achievement_map.keys()
	ids.sort()

	for achievement_id in ids:
		var achievement: Dictionary = achievement_map.get(achievement_id, {})
		var card: PanelContainer = _make_card(achievement_id, achievement)
		grid.add_child(card)

func _make_card(achievement_id: String, achievement: Dictionary) -> PanelContainer:
	var unlocked: bool = AchievementManager.is_unlocked(achievement_id)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(260, 180)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.18, 0.20, 0.28) if unlocked else Color(0.12, 0.12, 0.15)
	panel_style.border_color = Color(0.85, 0.74, 0.34) if unlocked else Color(0.32, 0.32, 0.36)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	card.add_theme_stylebox_override("panel", panel_style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(content)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	content.add_child(top)

	var icon_bg := PanelContainer.new()
	icon_bg.custom_minimum_size = Vector2(42, 42)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.95, 0.8, 0.35) if unlocked else Color(0.45, 0.45, 0.48)
	icon_style.corner_radius_top_left = 8
	icon_style.corner_radius_top_right = 8
	icon_style.corner_radius_bottom_left = 8
	icon_style.corner_radius_bottom_right = 8
	icon_bg.add_theme_stylebox_override("panel", icon_style)
	var icon_label := Label.new()
	icon_label.text = "★"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_label.add_theme_font_size_override("font_size", 22)
	icon_bg.add_child(icon_label)
	top.add_child(icon_bg)

	var title := Label.new()
	title.text = achievement.get("name", "成就")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.clip_text = true
	#title.text_overrun_behavior = TextServer.OVERRUN_TRUNCATE_ELLIPSIS
	top.add_child(title)

	var desc := Label.new()
	desc.text = achievement.get("description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.clip_text = true
	desc.modulate = Color(0.85, 0.85, 0.9)
	content.add_child(desc)

	var progress := Label.new()
	var current_value: int = AchievementManager.get_progress(achievement_id)
	var target_value: int = int(achievement.get("target", 0))
	progress.text = str(current_value) + "/" + str(target_value)
	progress.add_theme_font_size_override("font_size", 13)
	progress.modulate = Color(0.9, 0.9, 0.6)
	content.add_child(progress)

	var status := Label.new()
	status.text = "已解锁" if unlocked else "未解锁"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_theme_font_size_override("font_size", 12)
	status.modulate = Color(0.75, 0.96, 0.6) if unlocked else Color(0.7, 0.7, 0.72)
	content.add_child(status)

	return card
