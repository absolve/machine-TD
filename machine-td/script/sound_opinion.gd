extends VBoxContainer

@export var busName='Master':
	set(val):
		busNameLabel.text=str(val)
		sound.bus=val
		busName=val
		
@export var volume:float=0.0 :
	set(val):
		volume=val
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(busName), linear_to_db(volume))
		

@onready var busNameLabel=$name
@onready var sound=$sound
