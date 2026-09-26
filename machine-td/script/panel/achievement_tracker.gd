extends Node
## 关卡内成就记录器（挂在 map 场景的根节点下）
##
## 职责：把一局游戏里发生的战斗事件换算成成就进度，并决定"什么时候落盘"。
## 成就的目标值、解锁判定和存档都由 AchievementManager / UserData 负责，这里不重复实现。
##
## 成就分成两类处理：
##   累计型（ground_breaker 地面清扫者 / iron_hunter 重装猎手 / sky_guardian 天空守卫）
##       每次击杀直接累加，跨关卡一直累积。
##   单局型（full_armory 全域火力 / chain_reaction 连锁反应）
##       只统计本局进度，用"和历史最好成绩比大小"的方式提交，避免下一局的低分把记录覆盖掉。
##
## 落盘策略：进度用 auto_save=false 只改内存，否则每击杀一个敌人都要写一次存档文件。
## 通关结算和离开场景（_exit_tree）时统一 flush 一次；
## 解锁瞬间 AchievementManager.unlock() 内部会自己存档，不受这里影响。

# 单局型成就的目标（用于日志/校验，实际目标值以 AchievementManager 为准）
const RUN_BEST_ACHIEVEMENTS: Array[String] = ["full_armory", "chain_reaction"]

var _tower_types_used: Dictionary = {} # 本局用过的塔类型（全域火力）
var _chain_kills: int = 0 # 本局由特斯拉/火箭塔击杀的数量（连锁反应）


func _ready() -> void:
	Game.enemyDefeated.connect(_on_enemy_defeated)
	TowerUpgradeManager.tower_leveled_up.connect(_on_tower_leveled_up)


func _exit_tree() -> void:
	# 中途退回主菜单 / 重开关卡时，把还没落盘的进度补上
	flush()


# ---------- 击杀类 ----------

func _on_enemy_defeated(enemy, source) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return

	# 天空守卫 / 地面清扫者：按是否飞行分流
	if enemy.flying:
		AchievementManager.add_progress("sky_guardian", 1, false)
	else:
		AchievementManager.add_progress("ground_breaker", 1, false)

	# 重装猎手：重型坦克 / 装甲坦克
	if enemy.enemyType == Game.enemyType.heavyTank or enemy.enemyType == Game.enemyType.armoredTank:
		AchievementManager.add_progress("iron_hunter", 1, false)

	# 连锁反应：本局内由特斯拉线圈塔或火箭塔造成的击杀
	var tower := source as Tower
	if tower != null and (tower.type == Game.towerType.teslaCoilTower or tower.type == Game.towerType.rocketTower):
		_chain_kills += 1
		_submit_run_best("chain_reaction", _chain_kills)


# ---------- 建造类 ----------

# 由 map.placeTower 在塔真正放置成功后调用
func record_tower_built(tower_type) -> void:
	_tower_types_used[tower_type] = true
	_submit_run_best("full_armory", _tower_types_used.size())


# ---------- 成长类 ----------

func _on_tower_leveled_up(_tower, level: int) -> void:
	# 老兵塔：任意一座塔升到满级
	if level >= TowerUpgradeManager.MAX_LEVEL:
		AchievementManager.set_progress("veteran_tower", TowerUpgradeManager.MAX_LEVEL, false)


# ---------- 关卡结算 ----------

# 由 map.finish() 在通关时调用
# flawless: 基地全程没掉血（等价于没有任何敌人逃脱）
# multi_route: 该关卡是多路线关卡（存在多条 Path2D）
func record_stage_cleared(stage_id: int, flawless: bool, multi_route: bool) -> void:
	if stage_id == 1:
		AchievementManager.set_progress("first_defense", 1, false)
	if flawless:
		AchievementManager.set_progress("perfect_base", 1, false)
		if multi_route:
			AchievementManager.set_progress("route_master", 1, false)
	flush()


# ---------- 内部 ----------

# 单局型成就：只在超过历史最好成绩时提交，避免被下一局的低分覆盖
func _submit_run_best(achievement_id: String, value: int) -> void:
	if value > AchievementManager.get_progress(achievement_id):
		AchievementManager.set_progress(achievement_id, value, false)


# 把内存里的进度写进存档文件
func flush() -> void:
	AchievementManager.savePlayerAchievements()
