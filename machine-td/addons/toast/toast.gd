@tool
extends EditorPlugin

var pluginName="Toast"

func _enable_plugin():
	# Add autoloads here.
	add_autoload_singleton(pluginName,"res://addons/toast/autoLoad.gd")


func _disable_plugin():
	# Remove autoloads here.
	remove_autoload_singleton(pluginName)


func _enter_tree():
	# Initialization of the plugin goes here.
	pass


func _exit_tree():
	# Clean-up of the plugin goes here.
	pass
