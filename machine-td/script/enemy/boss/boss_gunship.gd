extends "res://script/enemy/boss/boss.gd"
## ⑥ 炮艇 `bossGunship` —— 打"没建防空"的人。
##
## **飞行**：只有无人机基地 / 激光塔 / 火箭塔打得到（tower.gd::canTargetAir）。
## 每 4 秒对最近的防御塔投弹。
##
## ⚠️ 单次伤害**封顶 15% 塔血量**：没有这层限制的话，"这一关没建防空"
##    会直接变成必崩（它一边飞一边把塔全拆了）。封顶之后它是"持续拆塔压力"，
##    而不是"见面就没了"。（用户确认要加这条，见 §19.4）
##
## EMP 对它无效是既有规则：emp_tower 进雷达时就过滤了 `area.flying`。

const BOMB_INTERVAL := 4.0
## 单次投弹最多打掉塔血量的这个比例
const MAX_HP_FRACTION := 0.15

var bombTimer: float = BOMB_INTERVAL
## 最近一次投弹的目标位置（用来画一条短暂的投弹线）
var bombLineTo: Vector2 = Vector2.ZERO
var bombLineLeft: float = 0.0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if bombLineLeft > 0.0:
		bombLineLeft = maxf(0.0, bombLineLeft - delta)
	if dead:
		return
	bombTimer -= delta
	if bombTimer > 0.0:
		return
	bombTimer = BOMB_INTERVAL
	bombNearestTower()


func bombNearestTower() -> void:
	var tower: Tower = pickTowerTarget()
	if tower == null or not is_instance_valid(tower):
		return
	var cap: int = maxi(1, int(ceil(float(tower.maxHp) * MAX_HP_FRACTION)))
	var damage: int = mini(atk, cap)
	tower.hurt(damage, self)
	ExplosionManage.playExplosion(tower.global_position, "light")
	SoundManage.playAt("tower_destroyed", tower.global_position, -14.0, randf_range(1.2, 1.35))
	bombLineTo = tower.global_position
	bombLineLeft = 0.25


func _draw() -> void:
	super._draw()
	if bombLineLeft > 0.0 and bombLineTo != Vector2.ZERO:
		draw_line(Vector2.ZERO, to_local(bombLineTo),
			Color(0.75, 0.65, 1.0, 0.55 * bombLineLeft / 0.25), 3.0)
