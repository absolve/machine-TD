extends Node2D

@export var levelId:int
@export var wave:int
@export var health:int
@export var money:int

@onready var waveTimer=$waveTimer
@onready var spawnerTimer=$spawnerTimer


var currWave=0
var enemyList=[]

var currentSpawner=[] #当前生产列表
