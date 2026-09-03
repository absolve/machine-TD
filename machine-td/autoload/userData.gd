extends Node


var language: String = "en"
var masterVolume: int = 100
var musicVolume: int = 100
var sfxVolume: int = 100
var musicMuted: bool = false
var sfxMuted: bool = false

#############玩家数据#####
var score: int = 0 # 分数
var gem: int = 0 # 宝石
var unlockedStages: Array[int] = [1] # 已解锁关卡，第一关默认解锁
var stageRatings: Dictionary = {} # 各关卡最高评分
var unlockedAchievements: Array[String] = [] # 已解锁成就
var achievementProgress: Dictionary = {} # 成就进度
#############

const SETTINGS_FILE_NAME := "user_settings.cfg"
const PLAYER_DATA_FILE_NAME := "player_data.cfg"
var settingsPath: String
var playerDataPath: String

func _ready() -> void:
	settingsPath = getSettingsPath()
	playerDataPath = getPlayerDataPath()
	loadSettings()
	loadPlayerData()

func getSettingsPath() -> String:
	return getFilePath(SETTINGS_FILE_NAME)

func getPlayerDataPath() -> String:
	return getFilePath(PLAYER_DATA_FILE_NAME)

#获取文件路径
func getFilePath(file_name: String) -> String:
	if OS.has_feature("web") or OS.has_feature("editor"):
		return "user://" + file_name
	return OS.get_executable_path().get_base_dir().path_join(file_name)

#获取设置
func loadSettings() -> void:
	var config := ConfigFile.new()
	if config.load(settingsPath) != OK:
		return
	language = str(config.get_value("general", "language", language))
	masterVolume = clampi(int(config.get_value("volume", "master", masterVolume)), 0, 100)
	musicVolume = clampi(int(config.get_value("volume", "music", musicVolume)), 0, 100)
	sfxVolume = clampi(int(config.get_value("volume", "sfx", sfxVolume)), 0, 100)
	musicMuted = bool(config.get_value("volume", "musicMuted", musicMuted))
	sfxMuted = bool(config.get_value("volume", "sfxMuted", sfxMuted))

func saveSettings() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "language", language)
	config.set_value("volume", "master", masterVolume)
	config.set_value("volume", "music", musicVolume)
	config.set_value("volume", "sfx", sfxVolume)
	config.set_value("volume", "musicMuted", musicMuted)
	config.set_value("volume", "sfxMuted", sfxMuted)
	config.save(settingsPath)

func loadPlayerData() -> void:
	var config := ConfigFile.new()
	if config.load(playerDataPath) != OK:
		return
	score = int(config.get_value("player", "score", score))
	gem = int(config.get_value("player", "gem", gem))
	var savedStages = config.get_value("player", "unlockedStages", unlockedStages)
	if savedStages is Array:
		unlockedStages.clear()
		for stage_id in savedStages:
			unlockedStages.append(int(stage_id))
	if 1 not in unlockedStages:
		unlockedStages.append(1)
	var savedRatings = config.get_value("player", "stageRatings", stageRatings)
	if savedRatings is Dictionary:
		stageRatings = savedRatings
	var savedAchievements = config.get_value("achievements", "unlocked", [])
	if savedAchievements is Array:
		unlockedAchievements.assign(savedAchievements)
	var savedProgress = config.get_value("achievements", "progress", {})
	if savedProgress is Dictionary:
		achievementProgress = savedProgress

func savePlayerData() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "score", score)
	config.set_value("player", "gem", gem)
	config.set_value("player", "unlockedStages", unlockedStages)
	config.set_value("player", "stageRatings", stageRatings)
	config.set_value("achievements", "unlocked", unlockedAchievements)
	config.set_value("achievements", "progress", achievementProgress)
	config.save(playerDataPath)

func isStageUnlocked(stage_id: int) -> bool:
	return stage_id == 1 or stage_id in unlockedStages

func getStageRating(stage_id: int) -> int:
	return int(stageRatings.get(str(stage_id), stageRatings.get(stage_id, 0)))

func recordStageCompletion(stage_id: int, rating: int) -> void:
	rating = clampi(rating, 0, 3)
	var old_rating := getStageRating(stage_id)
	if rating > old_rating:
		stageRatings[str(stage_id)] = rating
	if stage_id not in unlockedStages:
		unlockedStages.append(stage_id)
	var next_stage_id := stage_id + 1
	if next_stage_id <= 15 and next_stage_id not in unlockedStages:
		unlockedStages.append(next_stage_id)
	var reward_gem = max(rating - old_rating, 0)
	gem += reward_gem
	score += rating * 100
	savePlayerData()
