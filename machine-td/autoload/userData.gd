extends Node


# 语言。空字符串 = 跟随系统，首次启动时由 applyLanguage() 落定并写回。
# 之前默认写死 "en"，而且只有进过设置面板才会 set_locale，
# 结果没进过设置的玩家会看到「翻译键全部回退成英文、硬编码中文原样显示」的混排。
var language: String = ""
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
const SETTINGS_SCHEMA := 2
const PLAYER_DATA_FILE_NAME := "player_data.cfg"
var settingsPath: String
var playerDataPath: String
# 旧 schema 的设置被迁移过，需要回写一次（否则每次启动都要重新判定语言）
var _needsSettingsSave := false

func _ready() -> void:
	settingsPath = getSettingsPath()
	playerDataPath = getPlayerDataPath()
	loadSettings()
	loadPlayerData()
	applyLanguage()
	if _needsSettingsSave:
		saveSettings()
		_needsSettingsSave = false

# 把当前语言应用到全局。以前这段只在设置面板里执行，
# 没进过设置页就不会调用 set_locale → tr() 拿不到中文。
func applyLanguage() -> void:
	if language.is_empty():
		# OS.get_locale() 形如 "zh_CN" / "en_US"
		language = "zh" if OS.get_locale().begins_with("zh") else "en"
	TranslationServer.set_locale(language)

func getSettingsPath() -> String:
	return getFilePath(SETTINGS_FILE_NAME)

func getPlayerDataPath() -> String:
	return getFilePath(PLAYER_DATA_FILE_NAME)

#获取文件路径
func getFilePath(file_name: String) -> String:
	return "user://" + file_name

#获取设置
func loadSettings() -> void:
	var config := ConfigFile.new()
	if config.load(settingsPath) != OK:
		return
	# schema 1 及更早：language 默认写死 "en"，玩家就算从没选过语言也会被存成 en。
	# 升级时这种"继承来的 en"要按系统语言重新判定，否则老玩家永远停在英文。
	var schema := int(config.get_value("general", "schema", 1))
	language = str(config.get_value("general", "language", language))
	if schema < SETTINGS_SCHEMA and language == "en" and OS.get_locale().begins_with("zh"):
		language = "zh"
	if schema < SETTINGS_SCHEMA:
		_needsSettingsSave = true
	masterVolume = clampi(int(config.get_value("volume", "master", masterVolume)), 0, 100)
	musicVolume = clampi(int(config.get_value("volume", "music", musicVolume)), 0, 100)
	sfxVolume = clampi(int(config.get_value("volume", "sfx", sfxVolume)), 0, 100)
	musicMuted = bool(config.get_value("volume", "musicMuted", musicMuted))
	sfxMuted = bool(config.get_value("volume", "sfxMuted", sfxMuted))

func saveSettings() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "schema", SETTINGS_SCHEMA)
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
	var error := config.save(playerDataPath)
	if error != OK:
		push_error("无法保存玩家进度: %s (%s)" % [playerDataPath, error])

func isStageUnlocked(stage_id: int) -> bool:
	return stage_id == 1 or stage_id in unlockedStages

func getStageRating(stage_id: int) -> int:
	return int(stageRatings.get(str(stage_id), stageRatings.get(stage_id, 0)))

func recordStageCompletion(stage_id: int, rating: int) -> int:
	rating = clampi(rating, 0, 3)
	# rating 为 0 表示基地被打爆，不算通关：
	# 不记星级、不解锁关卡、不发宝石（这里兜底，防止调用方漏判）
	if rating <= 0:
		return 0
	var old_rating := getStageRating(stage_id)
	var first_completion := not stageRatings.has(str(stage_id)) and not stageRatings.has(stage_id)
	if rating > old_rating:
		stageRatings[str(stage_id)] = rating
	if stage_id not in unlockedStages:
		unlockedStages.append(stage_id)
	var next_stage_id := stage_id + 1
	for stage in StageData.allStage:
		if int(stage.get("id", -1)) == next_stage_id:
			if next_stage_id not in unlockedStages:
				unlockedStages.append(next_stage_id)
			break
	var reward_gem := 0
	for stage in StageData.allStage:
		if int(stage.get("id", -1)) == stage_id:
			reward_gem = int(stage.get("gemReward", 0)) if first_completion else 0
			break
	gem += reward_gem
	score += rating * 100
	savePlayerData()
	return reward_gem
