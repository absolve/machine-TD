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

const EMPTY_PERMANENT_STATS: Dictionary = {
	"completed_stages": [],
	"ground_kills": 0,
	"air_kills": 0,
	"heavy_kills": 0,
	"highest_tower_level": 1
}

var unlocked_achievements: Array[String] = []
var permanent_stats: Dictionary = EMPTY_PERMANENT_STATS.duplicate(true)
var achievement_progress: Dictionary = {}
var run_stats: Dictionary = {}

func _ready() -> void:
	loadPlayerAchievements()
	begin_run()

func loadPlayerAchievements() -> void:
	unlocked_achievements = UserData.unlockedAchievements.duplicate()
	achievement_progress = UserData.achievementProgress.duplicate(true)

func begin_run() -> void:
	run_stats = {
		"tower_types": [],
		"special_tower_kills": 0,
		"escaped_enemies": 0,
		"starting_health": 0,
		"remaining_health": 0,
		"multi_route": false
	}

func get_achievement(achievement_id: String) -> Dictionary:
	return ACHIEVEMENTS.get(achievement_id, {}).duplicate(true)

func get_all_achievements() -> Dictionary:
	return ACHIEVEMENTS.duplicate(true)

func is_unlocked(achievement_id: String) -> bool:
	return achievement_id in unlocked_achievements

func get_progress(achievement_id: String) -> int:
	match achievement_id:
		"ground_breaker":
			return int(achievement_progress.get(achievement_id, 0))
		"iron_hunter":
			return int(achievement_progress.get(achievement_id, 0))
		"sky_guardian":
			return int(achievement_progress.get(achievement_id, 0))
		"full_armory":
			return run_stats.tower_types.size()
		"chain_reaction":
			return run_stats.special_tower_kills
		"veteran_tower":
			return int(achievement_progress.get(achievement_id, 1))
	return 0

func unlock(achievement_id: String) -> bool:
	if not ACHIEVEMENTS.has(achievement_id) or is_unlocked(achievement_id):
		return false
	unlocked_achievements.append(achievement_id)
	UserData.unlockedAchievements = unlocked_achievements.duplicate()
	UserData.savePlayerData()
	achievement_unlocked.emit(achievement_id, get_achievement(achievement_id))
	return true
