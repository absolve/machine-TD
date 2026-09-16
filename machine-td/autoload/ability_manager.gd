extends Node
## 能力技能系统（战斗内主动技能）
##
## 关卡通过 StageData.stageAbilities 声明本关启用哪些技能，例如：
##     const stageAbilities := { 4: ["bombard", "invincible"] }
## 没有配置的关卡不会出现技能条。
##
## 冷却时间不在这里维护：每个技能槽 ability_slot.tscn 内置一个 Timer 负责计时。
## 本管理器只负责"能不能放、往哪放、放完通知谁"。
##
## 技能定义集中在下面的 ABILITIES 表里，新增技能只需要加一条。
## icon 目前是占位素材，之后设计好图标直接改路径即可。

signal ability_activated(ability_id: String, target)
signal selection_started(ability_id: String)
signal selection_ended(ability_id: String)
signal ability_failed(ability_id: String, reason: String)

# 技能的目标类型
enum TargetType {
	NONE,      # 无需选择目标，点击立即生效
	POSITION,  # 需要点击地图上的一个位置（范围类技能都用这个）
}

## 技能定义表（新增技能只改这里）
## icon 为占位素材，替换图标时只改这个路径
const ABILITIES: Dictionary = {
	"bombard": {
		"name_key": "_ability_bombard_name",
		"desc_key": "_ability_bombard_desc",
		"icon": "res://sprite/explosion1.png",
		"target_type": TargetType.POSITION,
		"cooldown": 30.0,
		"effect": {"type": "area_damage", "radius": 140.0, "damage": 200},
	},
	"invincible": {
		"name_key": "_ability_invincible_name",
		"desc_key": "_ability_invincible_desc",
		"icon": "res://sprite/shield.png",
		"target_type": TargetType.POSITION,
		"cooldown": 45.0,
		"effect": {"type": "tower_invincible", "radius": 220.0, "duration": 8.0},
	},
}

# 本关启用的技能 id（顺序即 UI 显示顺序）
var _active_ids: Array[String] = []
# 当前正在等待玩家选择目标的技能 id（空串表示没有在选择）
var _selecting_id: String = ""

# 图标缓存，避免每次重建 UI 都重新加载
var _icon_cache: Dictionary = {}


# ===== 战斗开始时由 map 调用 =====
# ability_ids 来自 StageData.stageAbilities；空数组表示本关没有技能
func begin_battle(ability_ids: Array) -> void:
	_active_ids.clear()
	_selecting_id = ""
	for id in ability_ids:
		var key := str(id)
		if not ABILITIES.has(key):
			push_warning("未知的技能 id，已忽略: " + key)
			continue
		if key in _active_ids:
			continue
		_active_ids.append(key)


# ===== 查询 =====
func get_active_ids() -> Array[String]:
	return _active_ids.duplicate()


func get_definition(ability_id: String) -> Dictionary:
	return ABILITIES.get(ability_id, {})


# 技能显示名（多语言，缺失时回退到 id）
func get_display_name(ability_id: String) -> String:
	var data := get_definition(ability_id)
	var key := str(data.get("name_key", ""))
	if key.is_empty():
		return ability_id
	var translated := tr(key)
	return ability_id if translated == key else translated


# 技能说明（多语言，缺失时回退为空串）
func get_description(ability_id: String) -> String:
	var data := get_definition(ability_id)
	var key := str(data.get("desc_key", ""))
	if key.is_empty():
		return ""
	var translated := tr(key)
	return "" if translated == key else translated


# 冷却总时长（技能槽用它设置内置 Timer 的 wait_time）
func get_cooldown_total(ability_id: String) -> float:
	return float(get_definition(ability_id).get("cooldown", 0.0))


# 图标（占位素材可能不存在，返回 null 时 UI 显示空槽）
func get_icon(ability_id: String) -> Texture2D:
	if _icon_cache.has(ability_id):
		return _icon_cache[ability_id]
	var path := str(get_definition(ability_id).get("icon", ""))
	var texture: Texture2D = null
	if not path.is_empty() and ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			texture = res
	_icon_cache[ability_id] = texture
	return texture


# ===== 目标选择状态 =====
func is_selecting() -> bool:
	return not _selecting_id.is_empty()


func get_selecting_id() -> String:
	return _selecting_id


# 正在等待"点击位置"的技能；map 用它决定要不要画范围预览
func is_selecting_position() -> bool:
	if _selecting_id.is_empty():
		return false
	return int(get_definition(_selecting_id).get("target_type", TargetType.NONE)) == TargetType.POSITION


# 当前选择中的技能范围（供预览绘制）
func get_selecting_radius() -> float:
	if _selecting_id.is_empty():
		return 0.0
	return float(get_definition(_selecting_id).get("effect", {}).get("radius", 0.0))


# ===== 触发流程 =====
# 玩家点击技能图标
func try_activate(ability_id: String) -> void:
	var data := get_definition(ability_id)
	if data.is_empty():
		return
	# 再次点击同一个技能 = 取消选择
	if _selecting_id == ability_id:
		cancel_selecting()
		return
	if is_selecting():
		cancel_selecting()
	var target_type := int(data.get("target_type", TargetType.NONE))
	if target_type == TargetType.NONE:
		_activate(ability_id, null)
		return
	# 需要选目标：进入选择模式，等 map 调用 confirm_target
	_selecting_id = ability_id
	selection_started.emit(ability_id)


# 玩家在地图上选好目标后由 map 调用
func confirm_target(target) -> void:
	if _selecting_id.is_empty():
		return
	var id := _selecting_id
	_selecting_id = ""
	selection_ended.emit(id)
	_activate(id, target)


# 玩家取消选择（右键 / ESC / 再点一次图标）
func cancel_selecting() -> void:
	if _selecting_id.is_empty():
		return
	var id := _selecting_id
	_selecting_id = ""
	selection_ended.emit(id)


# ===== 生效 =====
func _activate(ability_id: String, target) -> void:
	var data := get_definition(ability_id)
	if not _apply_effect(data.get("effect", {}), target):
		# 目标无效（比如点到空地）：不进入冷却，让玩家重新选
		ability_failed.emit(ability_id, "no_target")
		return
	# 冷却由技能槽内的 Timer 负责，这里只通知"已生效"
	ability_activated.emit(ability_id, target)


# 返回 true 表示效果已成功生效
func _apply_effect(effect: Dictionary, target) -> bool:
	if Game.map == null:
		return false
	match str(effect.get("type", "")):
		"area_damage":
			if not (target is Vector2):
				return false
			return Game.map.area_damage(target, float(effect.get("radius", 0.0)), int(effect.get("damage", 0)))
		"tower_invincible":
			if not (target is Vector2):
				return false
			return Game.map.area_invincible(target, float(effect.get("radius", 0.0)), float(effect.get("duration", 0.0)))
	return false
