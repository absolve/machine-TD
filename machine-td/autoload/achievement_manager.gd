extends Node

signal achievement_unlocked(achievement_id: String, achievement: Dictionary)

const ACHIEVEMENTS: Dictionary = {
	"first_defense": {
		"name": "初次防守",
		"category": "stage",
		"description": "完成第 1 关",
		"target": 1,
		"reward_gem": 10,
		"reward_title": ""
	},
	"ground_breaker": {
		"name": "地面清扫者",
		"category": "combat",
		"description": "累计击败 100 个地面敌人",
		"target": 100,
		"reward_gem": 15,
		"reward_title": ""
	},
	"iron_hunter": {
		"name": "重装猎手",
		"category": "combat",
		"description": "累计击败 20 个重型坦克或装甲坦克",
		"target": 20,
		"reward_gem": 20,
		"reward_title": ""
	},
	"sky_guardian": {
		"name": "天空守卫",
		"category": "combat",
		"description": "累计击败 30 个空中敌人",
		"target": 30,
		"reward_gem": 20,
		"reward_title": "天空守卫"
	},
	"full_armory": {
		"name": "全域火力",
		"category": "build",
		"description": "同一关中使用过 7 种防御塔",
		"target": 7,
		"reward_gem": 25,
		"reward_title": ""
	},
	"chain_reaction": {
		"name": "连锁反应",
		"category": "build",
		"description": "单局内使用 Tesla 或火箭塔击败 5 个敌人",
		"target": 5,
		"reward_gem": 15,
		"reward_title": ""
	},
	"veteran_tower": {
		"name": "老兵塔",
		"category": "growth",
		"description": "任意一座塔升至 3 级",
		"target": 3,
		"reward_gem": 20,
		"reward_title": ""
	},
	"perfect_base": {
		"name": "零损防线",
		"category": "stage",
		"description": "不损失基地生命完成任意关卡",
		"target": 1,
		"reward_gem": 30,
		"reward_title": ""
	},
	"route_master": {
		"name": "路线掌控者",
		"category": "stage",
		"description": "在多路线关卡中胜利且没有敌人逃脱",
		"target": 1,
		"reward_gem": 30,
		"reward_title": "路线掌控者"
	}
}

var unlocked_achievements: Array[String] = []
var achievement_progress: Dictionary = {}

func _ready() -> void:
	loadPlayerAchievements()

func loadPlayerAchievements() -> void:
	unlocked_achievements = UserData.unlockedAchievements.duplicate()
	achievement_progress = UserData.achievementProgress.duplicate(true)

func savePlayerAchievements() -> void:
	UserData.unlockedAchievements = unlocked_achievements.duplicate()
	UserData.achievementProgress = achievement_progress.duplicate(true)
	UserData.savePlayerData()

func get_achievement(achievement_id: String) -> Dictionary:
	return ACHIEVEMENTS.get(achievement_id, {}).duplicate(true)

func get_all_achievements() -> Dictionary:
	return ACHIEVEMENTS.duplicate(true)

func is_unlocked(achievement_id: String) -> bool:
	return achievement_id in unlocked_achievements

func get_progress(achievement_id: String) -> int:
	return int(achievement_progress.get(achievement_id, 0))

func set_progress(achievement_id: String, value: int, auto_save: bool = true) -> int:
	if not ACHIEVEMENTS.has(achievement_id):
		return 0
	var progress := maxi(0, int(value))
	achievement_progress[achievement_id] = progress
	if auto_save:
		savePlayerAchievements()
	check_unlock(achievement_id)
	return progress

func add_progress(achievement_id: String, delta: int = 1, auto_save: bool = true) -> int:
	return set_progress(achievement_id, get_progress(achievement_id) + delta, auto_save)

func check_unlock(achievement_id: String) -> bool:
	if not ACHIEVEMENTS.has(achievement_id) or is_unlocked(achievement_id):
		return false
	var achievement: Dictionary = get_achievement(achievement_id)
	var target: int = int(achievement.get("target", 0))
	if get_progress(achievement_id) < target:
		return false
	unlock(achievement_id)
	return true

func unlock(achievement_id: String) -> bool:
	if not ACHIEVEMENTS.has(achievement_id) or is_unlocked(achievement_id):
		return false
	unlocked_achievements.append(achievement_id)
	savePlayerAchievements()
	achievement_unlocked.emit(achievement_id, get_achievement(achievement_id))
	return true
