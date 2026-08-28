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
	config.set_value("achievements", "unlocked", unlockedAchievements)
	config.set_value("achievements", "progress", achievementProgress)
	config.save(playerDataPath)
