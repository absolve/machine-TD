extends Node2D

class_name BaseTurret

enum OwnerType { ENEMY, TOWER }

const ENEMY_BULLET: PackedScene = preload("res://scene/bullet/enemy_bullet.tscn")
const TOWER_BULLET: PackedScene = preload("res://scene/bullet/gunBullet.tscn")

@export var ownerType: OwnerType = OwnerType.ENEMY
@export var atk: int = 10
@export var shootDelay: float = 1.0
@export var radarScope: float = 240.0
@export var rotationSpeed: float = 10.0
@export var muzzleOffset: float = 32.0
## 开火后坐距离（像素，沿炮管反方向）。详见 [method playTurretRecoil]。
@export var fireRecoil: float = 5.0

const RECOIL_BACK_TIME: float = 0.1
const RECOIL_RETURN_TIME: float = 0.1

var recoilTween: Tween
var turretOffsetBase: Vector2 = Vector2.ZERO
var turretOffsetCached: bool = false

var targets: Array[Area2D] = []
var canShot: bool = true

@onready var hostNode: Node2D = get_parent() as Node2D
@onready var turretSprite: AnimatedSprite2D = $Turret
@onready var muzzle: Marker2D = $Turret/Muzzle
@onready var radar: Area2D = $Radar
@onready var radarShape: CollisionShape2D = $Radar/CollisionShape2D
@onready var delayTimer: Timer = $Delay


func _ready() -> void:
	muzzle.position = Vector2(muzzleOffset, 0.0)
	delayTimer.wait_time = maxf(shootDelay, 0.01)
	var circle: CircleShape2D = radarShape.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		radarShape.shape = circle
	circle.radius = radarScope
	radar.collision_mask = 1 if ownerType == OwnerType.ENEMY else 2


func onRadarAreaEntered(area: Area2D) -> void:
	if isValidTarget(area) and not targets.has(area):
		targets.append(area)


func onRadarAreaExited(area: Area2D) -> void:
	targets.erase(area)


func onDelayTimeout() -> void:
	canShot = true


func isValidTarget(area: Area2D) -> bool:
	if ownerType == OwnerType.ENEMY:
		return area is Tower
	return area is Enemy


## 取**离自己最近**的有效目标；顺手把失效条目清掉。
##
## ⚠️ 距离基准是**炮塔自己**（本节点），不是宿主中心 [member hostNode]：
##    实验坦克的 4 座炮塔共用一个宿主，若按宿主中心算，4 座会永远锁同一座塔、齐射同一目标；
##    按各自位置算，四角炮塔会分别打"离自己最近"的那座塔，火力自然散开。
##    这里用炮塔根节点（固定的挂点）而不是会转动的 [member muzzle] 作基准 ——
##    用转动中的炮口算距离会形成反馈：瞄准改变 → 距离改变 → 换目标，两座近乎等距的塔之间会来回抖。
func pickTarget() -> Area2D:
	var bestTarget: Area2D = null
	var bestDistanceSquared: float = INF
	var validTargets: Array[Area2D] = []
	for area in targets:
		if not is_instance_valid(area) or not isValidTarget(area):
			continue
		validTargets.append(area)
		var distanceSquared: float = global_position.distance_squared_to(area.global_position)
		if distanceSquared < bestDistanceSquared:
			bestDistanceSquared = distanceSquared
			bestTarget = area
	targets = validTargets
	return bestTarget


func fireAt(target: Area2D) -> void:
	if not canShot or not is_instance_valid(target):
		return
	canShot = false
	var bulletScene: PackedScene = (
		ENEMY_BULLET if ownerType == OwnerType.ENEMY else TOWER_BULLET)
	var bullet = bulletScene.instantiate()
	var muzzlePosition: Vector2 = muzzle.global_position
	bullet.global_position = muzzlePosition
	bullet.angle = (target.global_position - muzzlePosition).angle()
	bullet.damage = atk
	if ownerType == OwnerType.TOWER:
		bullet.sourceTower = hostNode as Tower
	Game.addObj(bullet)
	SoundManage.playAt("mg_fire_b", muzzlePosition, -8.0, randf_range(0.94, 1.08))
	# 开火后坐（给塔用时会自己跳过：塔的 player 里已经有 "fire" 动画了）
	playTurretRecoil()
	delayTimer.start()


## 开火后坐：把炮塔贴图往后一顿再弹回（与 `enemy.gd::playTurretRecoil()` 同一套做法，
## 那里有为什么不用 AnimationPlayer 的完整说明）。
##
## 实验坦克的 4 座子炮塔（[code]ownerType = ENEMY[/code]）各自调用，所以 4 座会各弹各的。
## **防御塔不弹** —— 塔的 `player` 里本就有 "fire" 动画，这里再补一层会变成双重后坐。
## 只动 [member turretSprite] 的 `offset`（纯视觉，不带动 `Muzzle`）。
func playTurretRecoil() -> void:
	if ownerType != OwnerType.ENEMY:
		return
	# 基准 offset 第一次开火时记下来（场景里可能配过初值）
	if not turretOffsetCached:
		turretOffsetBase = turretSprite.offset
		turretOffsetCached = true
	if recoilTween != null and recoilTween.is_valid():
		recoilTween.kill()
	turretSprite.offset = turretOffsetBase
	recoilTween = create_tween()
	recoilTween.tween_property(turretSprite, "offset",
		turretOffsetBase + Vector2(-fireRecoil, 0.0), RECOIL_BACK_TIME)
	recoilTween.tween_property(turretSprite, "offset", turretOffsetBase, RECOIL_RETURN_TIME)


func _physics_process(delta: float) -> void:
	if hostNode == null or not is_instance_valid(hostNode):
		return
	var target: Area2D = pickTarget()
	if target == null:
		return
	var direction: Vector2 = target.global_position - muzzle.global_position
	if direction.length_squared() < 0.01:
		return
	var targetAngle: float = direction.angle() - global_rotation
	var angleDifference: float = wrapf(targetAngle - turretSprite.rotation, -PI, PI)
	turretSprite.rotation = lerp_angle(
		turretSprite.rotation, targetAngle, minf(1.0, rotationSpeed * delta))
	if absf(angleDifference) < 0.1:
		fireAt(target)