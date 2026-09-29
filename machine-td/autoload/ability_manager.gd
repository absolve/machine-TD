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
## 图标在 sprite/icon/ 下，128x128 简笔画风格。

signal abilityActivated(abilityId: String, target)
signal selectionStarted(abilityId: String)
signal selectionEnded(abilityId: String)
signal abilityFailed(abilityId: String, reason: String)
## 宝石数量变化（花掉技能宝石后发出）。顶栏标题栏据此刷新显示。
signal gemChanged(gem: int)

# 技能的目标类型
enum TargetType {
	NONE,      # 无需选择目标，点击立即生效
	POSITION,  # 需要点击地图上的一个位置（范围类技能都用这个）
}

## 技能定义表（新增技能只改这里）
## icon 路径指向 sprite/icon/ 下的图标
##
## ★ 数值规范（2026-09-26）：
##   · 技能改为**消耗宝石**（`gem_cost`），宝石来自首次通关奖励（UserData.gem）
##   · 冷却大幅缩短（原来 30 / 45 秒太长，一场战斗放不了几次）：
##     现在主要靠宝石数量来限制使用频率，冷却只是防止连点
##   · 放技能前必须 `UserData.gem >= gem_cost`，放出去才扣；
##     目标无效（点到空地）**不扣宝石、不进冷却**，让玩家重选
const ABILITIES: Dictionary = {
	"bombard": {
		"name_key": "_ability_bombard_name",
		"desc_key": "_ability_bombard_desc",
		"icon": "res://sprite/icon/ability_bombard.png",
		"target_type": TargetType.POSITION,
		"gem_cost": 1,
		"cooldown": 6.0,
		"effect": {"type": "area_damage", "radius": 100.0, "damage": 200},
	},
	"invincible": {
		"name_key": "_ability_invincible_name",
		"desc_key": "_ability_invincible_desc",
		"icon": "res://sprite/icon/ability_invincible.png",
		"target_type": TargetType.POSITION,
		"gem_cost": 1,
		"cooldown": 8.0,
		"effect": {"type": "tower_invincible", "radius": 120.0, "duration": 8.0},
	},
}

# 本关启用的技能 id（顺序即 UI 显示顺序）
var _activeIds: Array[String] = []
# 当前正在等待玩家选择目标的技能 id（空串表示没有在选择）
var _selectingId: String = ""

# 图标缓存，避免每次重建 UI 都重新加载
var _iconCache: Dictionary = {}


# ===== 战斗开始时由 map 调用 =====
# ability_ids 来自 StageData.stageAbilities；空数组表示本关没有技能
func beginBattle(abilityIds: Array) -> void:
	_activeIds.clear()
	_selectingId = ""
	for id in abilityIds:
		var key: String = str(id)
		if not ABILITIES.has(key):
			push_warning("未知的技能 id，已忽略: " + key)
			continue
		if key in _activeIds:
			continue
		_activeIds.append(key)


# ===== 查询 =====
func getActiveIds() -> Array[String]:
	return _activeIds.duplicate()


func getDefinition(abilityId: String) -> Dictionary:
	return ABILITIES.get(abilityId, {})


# 技能显示名（多语言，缺失时回退到 id）
func getDisplayName(abilityId: String) -> String:
	var data: Dictionary = getDefinition(abilityId)
	var key: String = str(data.get("name_key", ""))
	if key.is_empty():
		return abilityId
	var translated: String = tr(key)
	return abilityId if translated == key else translated


# 技能说明（多语言，缺失时回退为空串）
func getDescription(abilityId: String) -> String:
	var data: Dictionary = getDefinition(abilityId)
	var key: String = str(data.get("desc_key", ""))
	if key.is_empty():
		return ""
	var translated: String = tr(key)
	return "" if translated == key else translated


# 冷却总时长（技能槽用它设置内置 Timer 的 wait_time）
func getCooldownTotal(abilityId: String) -> float:
	return float(getDefinition(abilityId).get("cooldown", 0.0))


# ===== 宝石消耗 =====
# 技能现在要花宝石（宝石来源：首次通关奖励，存在 UserData.gem）

## 这个技能要花几颗宝石；没配置就是 0（不消耗）
func getGemCost(abilityId: String) -> int:
	return int(getDefinition(abilityId).get("gem_cost", 0))


## 宝石够不够放这个技能
func canAfford(abilityId: String) -> bool:
	return UserData.gem >= getGemCost(abilityId)


## 真正扣宝石。只在效果**确认生效**之后调用（见 _activate）。
## 扣完发 gem_changed，让顶栏的宝石数字立刻刷新。
func _spendGem(abilityId: String) -> void:
	var cost: int = getGemCost(abilityId)
	if cost <= 0:
		return
	UserData.gem = maxi(0, UserData.gem - cost)
	UserData.savePlayerData()
	gemChanged.emit(UserData.gem)


# 图标（占位素材可能不存在，返回 null 时 UI 显示空槽）
func getIcon(abilityId: String) -> Texture2D:
	if _iconCache.has(abilityId):
		return _iconCache[abilityId]
	var path: String = str(getDefinition(abilityId).get("icon", ""))
	var texture: Texture2D = null
	if not path.is_empty() and ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			texture = res
	_iconCache[abilityId] = texture
	return texture


# ===== 目标选择状态 =====
func isSelecting() -> bool:
	return not _selectingId.is_empty()


func getSelectingId() -> String:
	return _selectingId


# 正在等待"点击位置"的技能；map 用它决定要不要画范围预览
func isSelectingPosition() -> bool:
	if _selectingId.is_empty():
		return false
	return int(getDefinition(_selectingId).get("target_type", TargetType.NONE)) == TargetType.POSITION


# 当前选择中的技能范围（供预览绘制）
func getSelectingRadius() -> float:
	if _selectingId.is_empty():
		return 0.0
	return float(getDefinition(_selectingId).get("effect", {}).get("radius", 0.0))


# ===== 触发流程 =====
# 玩家点击技能图标
func tryActivate(abilityId: String) -> void:
	var data: Dictionary = getDefinition(abilityId)
	if data.is_empty():
		return
	# 再次点击同一个技能 = 取消选择（取消不花宝石）
	if _selectingId == abilityId:
		cancelSelecting()
		return
	if isSelecting():
		cancelSelecting()
	# ★ 宝石不够直接拦下（此时还没扣，只是拦）
	if not canAfford(abilityId):
		abilityFailed.emit(abilityId, "no_gem")
		return
	var target_type: int = int(data.get("target_type", TargetType.NONE))
	if target_type == TargetType.NONE:
		_activate(abilityId, null)
		return
	# 需要选目标：进入选择模式，等 map 调用 confirm_target
	_selectingId = abilityId
	selectionStarted.emit(abilityId)


# 玩家在地图上选好目标后由 map 调用
func confirmTarget(target) -> void:
	if _selectingId.is_empty():
		return
	var id: String = _selectingId
	_selectingId = ""
	selectionEnded.emit(id)
	_activate(id, target)


# 玩家取消选择（右键 / ESC / 再点一次图标）
func cancelSelecting() -> void:
	if _selectingId.is_empty():
		return
	var id: String = _selectingId
	_selectingId = ""
	selectionEnded.emit(id)


# ===== 生效 =====
func _activate(abilityId: String, target) -> void:
	var data: Dictionary = getDefinition(abilityId)
	if not _applyEffect(data.get("effect", {}), target):
		# 目标无效（比如点到空地）：**不扣宝石、不进冷却**，让玩家重新选
		abilityFailed.emit(abilityId, "no_target")
		return
	# ★ 效果确认生效后才扣宝石（扣完发 gem_changed 刷新顶栏）
	_spendGem(abilityId)
	# 冷却由技能槽内的 Timer 负责，这里只通知"已生效"
	abilityActivated.emit(abilityId, target)


# 返回 true 表示效果已成功生效
func _applyEffect(effect: Dictionary, target) -> bool:
	if Game.map == null:
		return false
	match str(effect.get("type", "")):
		"area_damage":
			if not (target is Vector2):
				return false
			return Game.map.areaDamage(target, float(effect.get("radius", 0.0)), int(effect.get("damage", 0)))
		"tower_invincible":
			if not (target is Vector2):
				return false
			return Game.map.areaInvincible(target, float(effect.get("radius", 0.0)), float(effect.get("duration", 0.0)))
	return false
