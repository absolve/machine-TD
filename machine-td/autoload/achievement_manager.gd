extends Node

signal achievement_unlocked(achievement_id: String, achievement: Dictionary)

const ACHIEVEMENTS: Dictionary = {
	"first_defense": {
		"name": "_Achv_first_defense_name",
		"category": "stage",
		"description": "_Achv_first_defense_desc",
		"icon": "res://sprite/red-flag.png",
		"target": 1,
		"reward_gem": 10,
		"reward_title": ""
	},
	"ground_breaker": {
		"name": "_Achv_ground_breaker_name",
		"category": "combat",
		"description": "_Achv_ground_breaker_desc",
		"icon": "res://sprite/tankBody_blue_outline.png",
		"target": 100,
		"reward_gem": 15,
		"reward_title": ""
	},
	"iron_hunter": {
		"name": "_Achv_iron_hunter_name",
		"category": "combat",
		"description": "_Achv_iron_hunter_desc",
		"icon": "res://sprite/tankBody_bigRed_outline.png",
		"target": 20,
		"reward_gem": 20,
		"reward_title": ""
	},
	"sky_guardian": {
		"name": "_Achv_sky_guardian_name",
		"category": "combat",
		"description": "_Achv_sky_guardian_desc",
		"icon": "res://sprite/Hel_12.png",
		"target": 30,
		"reward_gem": 20,
		"reward_title": "天空守卫"
	},
	"full_armory": {
		"name": "_Achv_full_armory_name",
		"category": "build",
		"description": "_Achv_full_armory_desc",
		"icon": "res://sprite/tower2.png",
		"target": 7,
		"reward_gem": 25,
		"reward_title": ""
	},
	"chain_reaction": {
		"name": "_Achv_chain_reaction_name",
		"category": "build",
		"description": "_Achv_chain_reaction_desc",
		"icon": "res://sprite/bolt.png",
		"target": 5,
		"reward_gem": 15,
		"reward_title": ""
	},
	"veteran_tower": {
		"name": "_Achv_veteran_tower_name",
		"category": "growth",
		"description": "_Achv_veteran_tower_desc",
		"icon": "res://sprite/star-4.png",
		"target": 3,
		"reward_gem": 20,
		"reward_title": ""
	},
	"perfect_base": {
		"name": "_Achv_perfect_base_name",
		"category": "stage",
		"description": "_Achv_perfect_base_desc",
		"icon": "res://sprite/shield.png",
		"target": 1,
		"reward_gem": 30,
		"reward_title": ""
	},
	"route_master": {
		"name": "_Achv_route_master_name",
		"category": "stage",
		"description": "_Achv_route_master_desc",
		"icon": "res://sprite/SolidArrow-Right.png",
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
