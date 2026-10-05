extends "res://script/enemy/enemy.gd"
## 侦察无人机：空中侦察型敌人。

## 旋翼自转速度（弧度/秒）。
const ROTOR_SPIN_SPEED: float = 22.0

## 四个旋翼节点（相邻两个反向转，看起来更像真四轴）。
@onready var rotors: Array = [$RotorFL, $RotorFR, $RotorBL, $RotorBR]


func _ready() -> void:
	parent = get_parent()
	setupEnemyInfo()


func _process(delta: float) -> void:
	for i: int in rotors.size():
		var rotor: Node2D = rotors[i]
		var direction: float = 1.0 if i % 2 == 0 else -1.0
		rotor.rotation = wrapf(rotor.rotation + ROTOR_SPIN_SPEED * direction * delta, 0.0, TAU)
	
