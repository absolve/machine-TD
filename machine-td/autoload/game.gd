extends Node

const app_vec="1.0.0"  #程序版本

enum bulletType {
	player, enemy
}

# 敌人类型（已定义场景的敌人）
enum enemyType {
	miniTank, mediumTank, heavyTank,
	# 推进型（地面）
	armoredTank, assaultBuggy, medic, suicideTruck,
	# 对抗型（地面）
	missileTruck,
	# 空中单位
	scoutDrone, attackHelicopter
}

# 塔类型
enum towerType {
	machineGunTower = 1000, cannonTower, rocketTower, EMPTower,
	droneBase, teslaCoilTower, laserTower
}

# 塔信息
const towerInfo = {
	towerType.machineGunTower: {
	"name": "_TowerName_machineGun",
	"atk": 20,
	"cost": 20,
	"reload": 0.2,
	"scope": 300,
	"hp": 120,
	"maxHp": 120,
	"initTime": 0.6,
	"desc": "_machineGunTowerDesc",
	"gridSize": Vector2i(1, 1)
	},
	towerType.cannonTower: {
	"name": "_TowerName_cannon",
	"atk": 30,
	"cost": 35,
	"reload": 0.8,
	"scope": 320,
	"hp": 180,
	"maxHp": 180,
	"initTime": 0.9,
	"desc": "_cannonTowerDesc",
	"gridSize": Vector2i(1, 1)
	},
	towerType.rocketTower: {
	"name": "_TowerName_rocket",
	"atk": 40,
	"cost": 50,
	"reload": 1.5,
	"scope": 350,
	"hp": 220,
	"maxHp": 220,
	"initTime": 1.2,
	"desc": "_rocketTowerDesc",
	"gridSize": Vector2i(1, 1)
	},
	towerType.EMPTower: {
	"name": "_TowerName_emp",
	"atk": 30,
	"cost": 45,
	"reload": 4.0,
	"scope": 280,
	"hp": 150,
	"maxHp": 150,
	"initTime": 1.5,
	"desc": "_EMPTowerDesc",
	"gridSize": Vector2i(1, 1)
	},
	towerType.droneBase: {
	"name": "_TowerName_drone",
	"atk": 8,
	"cost": 65,
	"reload": 0.1,
	"scope": 400,
	"hp": 200,
	"maxHp": 200,
	"initTime": 1.3,
	"desc": "_droneBaseDesc",
	"gridSize": Vector2i(2, 2)
	},
	towerType.teslaCoilTower: {
	"name": "_TowerName_tesla",
	"atk": 25,
	"cost": 65,
	"reload": 1.5,
	"scope": 400,
	"hp": 240,
	"maxHp": 240,
	"initTime": 1.4,
	"desc": "_teslaCoilTowerDesc",
	"gridSize": Vector2i(2, 2)
	},
	towerType.laserTower: {
	"name": "_TowerName_laser",
	"atk": 30,
	"cost": 90,
	"reload": 1,
	"scope": 450,
	"hp": 260,
	"maxHp": 260,
	"initTime": 1.6,
	"desc": "_laserTowerDesc",
	"gridSize": Vector2i(2, 2)
	},
}


# 敌人基础信息（结合 game_analysis 敌人设计，作为初始数值，后续可调参）
# 字段：
#   hp 血量 / speed 移动速度(像素每秒) / reward 击杀金币 / lossPoints 逃脱扣血 / rewardExp 击杀经验
#   armor 物理伤害减免(0~1,能量伤害无视) / flying 空中单位(仅无人机/激光塔可命中)
#   atk 单次攻击伤害(对抗型才有值，推进型为0) / shootDelay 开火间隔秒(对抗型才有值)
#   scope 雷达半径(像素)：对抗/支援型的攻击或支援范围，推进型为0(不参战，雷达不侦测)
#   role 行为定位（用于信息面板标签）：pusher 推进型 / attacker 对抗型 / support 支援型 / bomber 自爆型 / siege 远程打击型 / air 空中单位
# 攻击模式：直射型(DPS=atk/shootDelay) / 远程打击型(追踪导弹，DPS=atk/shootDelay) / 自爆型(一次性总伤害，shootDelay无意义) / 空中直射型(DPS=atk/shootDelay)
# 攻击节奏参考：己方塔射程 280~450(像素)，cellSize=64，即塔约 4.4~7 格
const enemyInfo = {
	enemyType.miniTank: {
		"name": "_EnemyName_miniTank",
		"hp": 100, "speed": 100, "reward": 5, "lossPoints": 1, "rewardExp": 2,
		"armor": 0.05, "flying": false, "atk": 0, "shootDelay": 1.0, "scope": 0, "role": "_EnemyRole_pusher"
	},
	enemyType.mediumTank: {
		"name": "_EnemyName_mediumTank",
		"hp": 200, "speed": 100, "reward": 8, "lossPoints": 2, "rewardExp": 4,
		"armor": 0.15, "flying": false, "atk": 15, "shootDelay": 1.5, "scope": 240, "role": "_EnemyRole_attacker"
	},
	enemyType.heavyTank: {
		"name": "_EnemyName_heavyTank",
		"hp": 600, "speed": 50, "reward": 20, "lossPoints": 3, "rewardExp": 10,
		"armor": 0.4, "flying": false, "atk": 0, "shootDelay": 1.0, "scope": 0, "role": "_EnemyRole_pusher"
	},
	enemyType.armoredTank: {
		"name": "_EnemyName_armoredTank",
		"hp": 400, "speed": 50, "reward": 15, "lossPoints": 2, "rewardExp": 8,
		"armor": 0.6, "flying": false, "atk": 0, "shootDelay": 1.0, "scope": 0, "role": "_EnemyRole_pusher"
	},
	enemyType.assaultBuggy: {
		"name": "_EnemyName_assaultBuggy",
		"hp": 80, "speed": 220, "reward": 4, "lossPoints": 1, "rewardExp": 2,
		"armor": 0.1, "flying": false, "atk": 0, "shootDelay": 1.0, "scope": 0, "role": "_EnemyRole_pusher"
	},
	enemyType.medic: {
		"name": "_EnemyName_medic",
		"hp": 120, "speed": 100, "reward": 10, "lossPoints": 1, "rewardExp": 5,
		"armor": 0.1, "flying": false, "atk": 20, "shootDelay": 8.0, "scope": 180, "role": "_EnemyRole_support"
	},
	enemyType.suicideTruck: {
		"name": "_EnemyName_suicideTruck",
		"hp": 60, "speed": 160, "reward": 3, "lossPoints": 1, "rewardExp": 2,
		"armor": 0.0, "flying": false, "atk": 150, "shootDelay": 0.0, "scope": 150, "role": "_EnemyRole_bomber"
	},
	enemyType.missileTruck: {
		"name": "_EnemyName_missileTruck",
		"hp": 180, "speed": 50, "reward": 12, "lossPoints": 2, "rewardExp": 6,
		"armor": 0.25, "flying": false, "atk": 35, "shootDelay": 3.0, "scope": 700, "role": "_EnemyRole_siege"
	},
	enemyType.scoutDrone: {
		"name": "_EnemyName_scoutDrone",
		"hp": 30, "speed": 160, "reward": 3, "lossPoints": 1, "rewardExp": 2,
		"armor": 0.0, "flying": true, "atk": 0, "shootDelay": 1.0, "scope": 0, "role": "_EnemyRole_air"
	},
	enemyType.attackHelicopter: {
		"name": "_EnemyName_attackHelicopter",
		"hp": 280, "speed": 100, "reward": 15, "lossPoints": 2, "rewardExp": 8,
		"armor": 0.2, "flying": true, "atk": 5, "shootDelay": 0.5, "scope": 300, "role": "_EnemyRole_air"
	},
}

#支持的语言
const language = [{'text': 'English', 'code': 'en' ,'id':0},
 {'text': '简体中文', 'code': 'zh' ,'id':1}]
	


@warning_ignore("unused_signal")
signal defeatEnemy # 击败敌人
@warning_ignore("unused_signal")
signal enemyEscape # 敌人逃脱
@warning_ignore("unused_signal")
signal selectTower # 选择塔
@warning_ignore("unused_signal")
signal placeTower # 放置塔
@warning_ignore("unused_signal")
signal refreshData # 游戏数据刷新
@warning_ignore("unused_signal")
signal sellTower # 出售塔
@warning_ignore("unused_signal")
signal repairTower # 修理塔（参数：花费, 塔节点）
@warning_ignore("unused_signal")
signal lastWave # 最后一波
@warning_ignore("unused_signal")
signal clickTower
@warning_ignore("unused_signal")
signal towerLocked # 玩家点了本关禁用的防御塔（tower_ui 发出，map 弹提示）
@warning_ignore("unused_signal")
signal clickEnemy # 点击敌人（在地图上选中敌人，由 enemy.gd 的 input_event 发出）
@warning_ignore("unused_signal")
signal enemyDefeated(enemy, source) # 敌人被击杀（成就统计用；在节点释放前发出）


var map = null

func addObj(obj):
	if map:
		map.add_child(obj)

# ===== 显示名 =====
# towerInfo / enemyInfo 的 "name"（以及 enemyInfo 的 "role"）里存的**直接就是翻译键**，
# 例如 "_TowerName_machineGun" / "_EnemyRole_pusher"。
# 所以取显示名只要一次 tr()，不再需要额外维护三张映射表。

func get_tower_display_name(tower_type) -> String:
	return tr(str(towerInfo.get(tower_type, {}).get("name", "")))


func get_enemy_display_name(enemy_type) -> String:
	return tr(str(enemyInfo.get(enemy_type, {}).get("name", "")))


# 敌人行为定位标签（role 字段同样是翻译键）
func get_enemy_role_name(enemy_type) -> String:
	return tr(str(enemyInfo.get(enemy_type, {}).get("role", "")))


# 取翻译；未找到对应 key（语言文件未导入）时回退到默认文本
func _t(key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	var translated := tr(key)
	return fallback if translated == key else translated
