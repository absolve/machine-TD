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
var gem: int = 10 # 默认有10个宝石
var unlockedStages: Array[int] = [1] # 已解锁关卡，第一关默认解锁
var stageRatings: Dictionary = {} # 各关卡最高评分
var unlockedAchievements: Array[String] = [] # 已解锁成就
var achievementProgress: Dictionary = {} # 成就进度

## ── 无尽模式记录 ──
var endlessBestWave: int = 0 # 历史最高波数
var endlessBestKills: int = 0 # 对应那局的击杀数（M3 补）
var endlessRuns: int = 0 # 无尽累计游玩次数

## ── 挑战模式通关记账 ──
## 存 "模式id:关卡id" 形式的键（如 "swarm:3"），表示该模式该关的宝石**已经发过**。
## 挑战模式不写 stageRatings（不记录星级，见 feature_design.md §17.6），
## 所以"是否首通"不能再靠 stageRatings 判断 —— 否则同一关每打一次都会被当成首通，
## 可以把宝石无限刷出来。用这张表单独记账。
var challengeCleared: Array[String] = []
#############

const SETTINGS_FILE_NAME := "user_settings.cfg"
const SETTINGS_SCHEMA := 2 # 设置架构版本
const PLAYER_DATA_FILE_NAME := "player_data.cfg"

## ── 星级奖励 ──
## 在「首次通关宝石」（`StageData` 的 `gemReward`）之外，按**最高星级**额外发放的宝石比例。
## 用比例而不是固定值：后期关卡基础奖励大（第 1 关 3、第 16 关 20），固定值会把高关卡奖励稀释掉。
## 1 星是保底通关，不给额外奖励 —— 否则等于把基础奖励白涨一档。
##
## ⚠️ 只按「最高星级的**提升**」结算差额（见 recordStageCompletion），
##    所以同一关反复打不会重复领、掉星也不会扣回去。这两个数值可以直接调，不影响存档结构。
const STAR_BONUS_RATIO: Dictionary = {
	2: 0.25, # 2 星：额外 25%
	3: 0.50, # 3 星：额外 50%
}

var settingsPath: String
var playerDataPath: String
# 旧 schema 的设置被迁移过，需要回写一次（否则每次启动都要重新判定语言）
var needsSettingsSave: bool = false

func _ready() -> void:
	settingsPath = getSettingsPath()
	playerDataPath = getPlayerDataPath()

	# 两个文件各自"读到了没有"。读不到有两种情况，都要当成"没有存档"处理：
	#   ① 第一次运行，文件还不存在
	#   ② 文件存在但内容坏了 / 读不动（ConfigFile.load 返回错误）
	var settingsLoaded: bool = loadSettings()
	var playerLoaded: bool = loadPlayerData()

	# 语言要在写盘之前定下来：language 为空时按系统语言判定，
	# 否则第一份 user_settings.cfg 会存下一个空字符串。
	applyLanguage()

	# ★ 首次运行 / 加载失败 → 立刻生成一份默认文件落盘。
	#   这样玩家的存档目录从第一次启动就是完整可读的，也便于直接改 cfg。
	if not settingsLoaded or needsSettingsSave:
		var settingsResult: int = saveSettings()
		needsSettingsSave = false
		if settingsResult == OK:
			print("[UserData] 生成默认设置: ", settingsPath)
		else:
			push_warning("默认设置写入失败: %s (err %d)" % [settingsPath, settingsResult])

	if not playerLoaded:
		if savePlayerData():
			print("[UserData] 生成默认存档: ", playerDataPath)

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

## 存档目录：**编辑器里用 user://，打包后放在可执行文件旁边**。
##
## 打包成 exe 后存档跟着游戏走 —— 绿色版、换机器、发给别人测试都不会丢进度，
## 也方便直接看/改 cfg。web 构建没有"可执行文件目录"这个概念（res:// 在浏览器里
## 是只读的虚拟文件系统），只能继续用 user://（Emscripten 会落到 IndexedDB）。
##
## 返回的是**绝对路径**，不要在前面拼 "user://" 之类的前缀。
##
## 注意：打包版**不会**去 user:// 里捞旧存档。发布出来的包就是全新开局，
## 不会把开发机上那份存档悄悄带进玩家的游戏目录。
func getFilePath(file_name: String) -> String:
	if OS.has_feature("web") or OS.has_feature("editor"):
		return "user://" + file_name
	return OS.get_executable_path().get_base_dir().path_join(file_name)


## 读取设置并兼容旧版语言配置，避免升级后覆盖玩家的系统语言选择。
## 返回是否**成功读到了设置**；false = 第一次运行或文件损坏，调用方应落盘默认值。
##
## ⚠️ 只判 `ConfigFile.load()` 的返回值是不够的 —— 实测它对「空文件 / 纯乱码 /
##    二进制垃圾」统统返回 OK，只是解析出**空配置**。所以必须再确认 `[general]`
##    段真的在（那是这份文件的骨架，任何一版都会写）。
func loadSettings() -> bool:
	var config: ConfigFile = ConfigFile.new()
	if config.load(settingsPath) != OK:
		return false
	if not config.has_section("general"):
		return false
	# schema 1 及更早：language 默认写死 "en"，玩家就算从没选过语言也会被存成 en。
	# 升级时这种"继承来的 en"要按系统语言重新判定，否则老玩家永远停在英文。
	var schema: int = int(config.get_value("general", "schema", 1))
	language = str(config.get_value("general", "language", language))
	if schema < SETTINGS_SCHEMA and language == "en" and OS.get_locale().begins_with("zh"):
		language = "zh"
	if schema < SETTINGS_SCHEMA:
		needsSettingsSave = true
	masterVolume = clampi(int(config.get_value("volume", "master", masterVolume)), 0, 100)
	musicVolume = clampi(int(config.get_value("volume", "music", musicVolume)), 0, 100)
	sfxVolume = clampi(int(config.get_value("volume", "sfx", sfxVolume)), 0, 100)
	musicMuted = bool(config.get_value("volume", "musicMuted", musicMuted))
	sfxMuted = bool(config.get_value("volume", "sfxMuted", sfxMuted))
	return true

## 写设置。返回 ConfigFile.save 的结果，调用方据此决定要不要报错。
func saveSettings() -> int:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("general", "schema", SETTINGS_SCHEMA)
	config.set_value("general", "language", language)
	config.set_value("volume", "master", masterVolume)
	config.set_value("volume", "music", musicVolume)
	config.set_value("volume", "sfx", sfxVolume)
	config.set_value("volume", "musicMuted", musicMuted)
	config.set_value("volume", "sfxMuted", sfxMuted)
	return config.save(settingsPath)

## 读玩家存档。返回是否**成功读到了存档**；false = 第一次运行或文件损坏，
## 调用方应落盘一份默认存档。
##
## ⚠️ 同 loadSettings()：`ConfigFile.load()` 对空文件 / 乱码也返回 OK，
##    所以要再确认 `[player]` 段存在。少了这一层，"存档被写坏"会表现成
##    "进度静默清零"，玩家只会觉得白玩了。
func loadPlayerData() -> bool:
	var config: ConfigFile = ConfigFile.new()
	if config.load(playerDataPath) != OK:
		return false
	if not config.has_section("player"):
		return false
	score = int(config.get_value("player", "score", score))
	gem = int(config.get_value("player", "gem", gem))
	var savedStages = config.get_value("player", "unlockedStages", unlockedStages)
	if savedStages is Array:
		unlockedStages.clear()
		for stageId in savedStages:
			unlockedStages.append(int(stageId))
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
	# 无尽记录：老存档没有这三项，缺了就用默认值（0），不能报错

	endlessBestWave = int(config.get_value("endless", "bestWave", endlessBestWave))
	endlessBestKills = int(config.get_value("endless", "bestKills", endlessBestKills))
	endlessRuns = int(config.get_value("endless", "runs", endlessRuns))
	# 挑战模式记账：老存档没有这一项，缺了就用空数组（不报错）
	var savedChallenge = config.get_value("player", "challengeCleared", [])
	if savedChallenge is Array:
		challengeCleared.clear()
		for key in savedChallenge:
			challengeCleared.append(str(key))
	return true


## 写玩家存档。返回是否成功。
## ⚠️ 这里**不**在失败时 push_error：存档位置在个别环境下可能是只读的
##    （比如直接把游戏放在 Program Files 下），每次掉宝石都刷一条错误会很吵。
##    调用方按需处理返回值。
func savePlayerData() -> bool:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("player", "score", score)
	config.set_value("player", "gem", gem)
	config.set_value("player", "unlockedStages", unlockedStages)
	config.set_value("player", "stageRatings", stageRatings)
	config.set_value("achievements", "unlocked", unlockedAchievements)
	config.set_value("achievements", "progress", achievementProgress)
	config.set_value("endless", "bestWave", endlessBestWave)
	config.set_value("endless", "bestKills", endlessBestKills)
	config.set_value("endless", "runs", endlessRuns)
	config.set_value("player", "challengeCleared", challengeCleared)
	var error: int = config.save(playerDataPath)
	if error != OK:
		push_warning("无法保存玩家进度: %s (%s)" % [playerDataPath, error])
		return false
	return true


## 发放宝石并**立刻落盘**。
##
## 关卡中途掉落的宝石（击败特殊敌人）必须马上存：玩家可能在结算前退出/重开，
## 若拖到 `recordStageCompletion()` 才写盘，这部分奖励就丢了。
## 掉落是低频事件（只有特殊敌人），一次写盘的开销可以接受。
##
## ⚠️ 这里只负责数值与存档；顶栏刷新由调用方发 `AbilityManager.gemChanged` 通知
##   （map 已接在该信号上），不要在数据层直接摸 UI。
func addGem(amount: int) -> void:
	if amount <= 0:
		return
	gem += amount
	savePlayerData()

func isStageUnlocked(stageId: int) -> bool:
	return stageId == 1 or stageId in unlockedStages

func getStageRating(stageId: int) -> int:
	return int(stageRatings.get(str(stageId), stageRatings.get(stageId, 0)))

## 某关的**累计**星级奖励：该关基础宝石 × 星级对应比例。
## `baseGem` 由调用方查 `StageData` 传入（避免这里再扫一遍表）。
## 1 星及以下返回 0 —— 保底通关不额外奖励。
func starBonusTotal(baseGem: int, rating: int) -> int:
	if rating <= 1 or baseGem <= 0:
		return 0
	var ratio: float = float(STAR_BONUS_RATIO.get(rating, 0.0))
	# ceil 而非 round：3 关 baseGem=3 时 25% = 0.75，向下取整会变成 0，等于白给
	return int(ceil(float(baseGem) * ratio))


## 记录一次通关，返回**本次实际发放**的宝石：
## `{"gem": 总发放, "starBonus": 其中来自星级的差额}`
##
## 两种战斗模式的行为不同（见 feature_design.md §17.6）：
##
## **正常模式**（`recordsProgress = true`）—— 两笔奖励的规则不同，不要混为一谈：
##   · **首次通关宝石**（`StageData.gemReward`）：只在第一次通关发，防止反复刷关刷宝石。
##   · **星级奖励**（`STAR_BONUS_RATIO`）：按"最高星级的提升"发**差额**。
##     例：首次 1 星 → 只发基础；之后打出 3 星 → 只补 3 星与 1 星之间的差额。
##     所以「同一关反复打」不会重复领，「掉星重打」也不会扣回去（差额被夹到 0）。
##
## **挑战模式**（蜂群 / 铁流 / 精锐）—— **不写星级、不解锁下一关**，因此也不触发星级奖励。
##   回报改为：每个（模式, 关卡）**首次通关**发一次 `基础宝石 × gemScale`。
##   用 `challengeCleared` 单独记账 —— 不能用 stageRatings 判断"首通"，
##   因为挑战模式根本不写它，否则每次都会被当成首通、宝石可以无限刷。
##
## `modeId` 缺省为 "normal"，保证既有调用方（以及旧存档）行为不变。
func recordStageCompletion(stageId: int, rating: int, modeId: String = "normal") -> Dictionary:
	rating = clampi(rating, 0, 3)
	# rating 为 0 表示基地被打爆，不算通关：
	# 不记星级、不解锁关卡、不发宝石（这里兜底，防止调用方漏判）
	if rating <= 0:
		return {"gem": 0, "starBonus": 0}

	# 查本关基础宝石（星级奖励与挑战倍率都以它为基数）
	var baseGem: int = 0
	for stage in StageData.allStage:
		if int(stage.get("id", -1)) == stageId:
			baseGem = int(stage.get("gemReward", 0))
			break

	var def: Dictionary = Game.getBattleModeDef(modeId)
	var recordsProgress: bool = bool(def.get("recordsProgress", true))
	if not recordsProgress:
		return recordChallengeClear(stageId, modeId, baseGem, float(def.get("gemScale", 1.0)), rating)

	var oldRating: int = getStageRating(stageId)
	var firstCompletion: bool = not stageRatings.has(str(stageId)) and not stageRatings.has(stageId)
	if rating > oldRating:
		stageRatings[str(stageId)] = rating
	if stageId not in unlockedStages:
		unlockedStages.append(stageId)
	var nextStageId: int = stageId + 1
	for stage in StageData.allStage:
		if int(stage.get("id", -1)) == nextStageId:
			if nextStageId not in unlockedStages:
				unlockedStages.append(nextStageId)
			break
	var rewardGem: int = baseGem if firstCompletion else 0
	# 星级奖励只发"提升的部分"；掉星时差值为负，夹到 0
	var starBonus: int = maxi(starBonusTotal(baseGem, rating) - starBonusTotal(baseGem, oldRating), 0)
	gem += rewardGem + starBonus
	score += rating * 100
	savePlayerData()
	return {"gem": rewardGem + starBonus, "starBonus": starBonus}


## 挑战模式通关：只发一次"模式 × 关卡"的宝石，**不写星级、不解锁关卡**。
## 单独拆出来是为了让两条分支都短到能一眼看完（原函数混在一起会很难读）。
func recordChallengeClear(
	stageId: int, modeId: String, baseGem: int, gemScale: float, rating: int) -> Dictionary:
	var key: String = "%s:%d" % [modeId, stageId]
	var rewardGem: int = 0
	if key not in challengeCleared:
		challengeCleared.append(key)
		rewardGem = int(ceil(float(baseGem) * gemScale))
	gem += rewardGem
	score += rating * 100
	savePlayerData()
	return {"gem": rewardGem, "starBonus": 0}
