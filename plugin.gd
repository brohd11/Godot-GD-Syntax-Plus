@tool
extends EditorPlugin

const PluginLogic = preload("res://addons/syntax_plus/src/syntax_plus_plugin_logic.gd")
var plugin_logic: PluginLogic

func _enter_tree() -> void:
	plugin_logic = PluginLogic.new(self)
	add_child(plugin_logic)

func _exit_tree() -> void:
	plugin_logic.queue_free()
