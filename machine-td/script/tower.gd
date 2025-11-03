extends Node2D


var hp  #防御塔血量
var radarScope=50 #雷达范围
var delay=0.1 #开火延迟



@onready var rader=$radar
@onready var base=$base
@onready var turret=$turret
@onready var mouseArea=$mouseArea
