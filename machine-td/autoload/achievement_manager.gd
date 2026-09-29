extends Node

signal achievementUnlocked(achievement_id: String, achievement: Dictionary)

const ACHIEVEMENTS: Dictionary = {
	"first_defense": {
		"name": "_Achv_first_defense_name",
		"category": "stage",
		"description": "_Achv_first_defense_desc",
		"icon": "res://sprite/icon/achv_first_defense.png",
		"target": 1,
		"reward_gem": 10,
		"reward_title": ""
	},
	"ground_breaker": {
		"name": "_Achv_ground_breaker_name",
		"category": "combat",
		"description": "_Achv_ground_breaker_desc",
		"icon": "res://sprite/icon/achv_ground_breaker.png",
		"target": 100,
		"reward_gem": 15,
		"reward_title": ""
	},
	"iron_hunter": {
		"name": "_Achv_iron_hunter_name",
		"category": "combat",
		"description": "_Achv_iron_hunter_desc",
		"icon": "res://sprite/icon/achv_iron_hunter.png",
		"target": 20,
		"reward_gem": 20,
		"reward_title": ""
	},
	"sky_guardian": {
		"name": "_Achv_sky_guardian_name",
		"category": "combat",
		"description": "_Achv_sky_guardian_desc",
		"icon": "res://sprite/icon/achv_sky_guardian.png",
		"target": 30,
		"reward_gem": 20,
		"reward_title": "天空守卫"
	},
	"full_armory": {
		"name": "_Achv_full_armory_name",
		"category": "build",
		"description": "_Achv_full_armory_desc",
		"icon": "res://sprite/icon/achv_full_armory.png",
		"target": 7,
		"reward_gem": 25,
		"reward_title": ""
	},
	"chain_reaction": {
		"name": "_Achv_chain_reaction_name",
		"category": "build",
		"description": "_Achv_chain_reaction_desc",
		"icon": "res://sprite/icon/achv_chain_reaction.png",
		"target": 5,
		"reward_gem": 15,
		"reward_title": ""
	},
	"veteran_tower": {
		"name": "_Achv_veteran_tower_name",
		"category": "growth",
		"description": "_Achv_veteran_tower_desc",
		"icon": "res://sprite/icon/achv_veteran_tower.png",
		"target": 3,
		"reward_gem": 20,
		"reward_title": ""
	},
	"perfect_base": {
		"name": "_Achv_perfect_base_name",
		"category": "stage",
		"description": "_Achv_perfect_base_desc",
		"icon": "res://sprite/icon/achv_perfect_base.png",
		"target": 1,
		"reward_gem": 30,
		"reward_title": ""
	},
	"route_master": {
		"name": "_Achv_route_master_name",
		"category": "stage",
		"description": "_Achv_route_master_desc",
		"icon": "res://sprite/icon/achv_route_master.png",
		"target": 1,
		"reward_gem": 30,
		"reward_title": "路线掌控者"
	}
}

var unlockedAchievements: Array[String] = []
var achievementProgress: Dictionary = {}

func _ready() -> void:
	loadPlayerAchievements()

func loadPlayerAchievements() -> void:
	unlockedAchievements = UserData.unlockedAchievements.duplicate()
	achievementProgress = UserData.achievementProgress.duplicate(true)

func savePlayerAchievements() -> void:
	UserData.unlockedAchievements = unlockedAchievements.duplicate()
	UserData.achievementProgress = achievementProgress.duplicate(true)
	UserData.savePlayerData()

func getAchievement(achievement_id: String) -> Dictionary:
	return ACHIEVEMENTS.get(achievement_id, {}).duplicate(true)

func getAllAchievements() -> Dictionary:
	return ACHIEVEMENTS.duplicate(true)

func isUnlocked(achievement_id: String) -> bool:
	return achievement_id in unlockedAchievements

func getProgress(achievement_id: String) -> int:
	return int(achievementProgress.get(achievement_id, 0))

func setProgress(achievement_id: String, value: int, auto_save: bool = true) -> int:
	if not ACHIEVEMENTS.has(achievement_id):
		return 0
	var progress: int = maxi(0, int(value))
	achievementProgress[achievement_id] = progress
	if auto_save:
		savePlayerAchievements()
	checkUnlock(achievement_id)
	return progress

func addProgress(achievement_id: String, delta: int = 1, auto_save: bool = true) -> int:
	return setProgress(achievement_id, getProgress(achievement_id) + delta, auto_save)

func checkUnlock(achievement_id: String) -> bool:
	if not ACHIEVEMENTS.has(achievement_id) or isUnlocked(achievement_id):
		return false
	var achievement: Dictionary = getAchievement(achievement_id)
	var target: int = int(achievement.get("target", 0))
	if getProgress(achievement_id) < target:
		return false
	unlock(achievement_id)
	return true

func unlock(achievement_id: String) -> bool:
	if not ACHIEVEMENTS.has(achievement_id) or isUnlocked(achievement_id):
		return false
	unlockedAchievements.append(achievement_id)
	savePlayerAchievements()
	achievementUnlocked.emit(achievement_id, getAchievement(achievement_id))
	return true
