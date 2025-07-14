@tool
extends EditorPlugin

const EditorPluginManager = preload("res://addons/syntax_tags/src/remote/editor_plugin_manager.gd")
const EDITOR_PLUGINS_PATH = "res://addons/syntax_tags/src/editor_plugins/editor_plugins.json"
var editor_plugin_manager:EditorPluginManager

const MODULAR_BROWSER_PATH = "res://addons/modular_browser"

const TAG_EDITOR = preload("uid://cgmh6d384m4qe") # tag_editor.tscn
var window:Window

func _enter_tree() -> void:
	editor_plugin_manager = EditorPluginManager.new(self, EDITOR_PLUGINS_PATH, true)
	
	if not DirAccess.dir_exists_absolute(MODULAR_BROWSER_PATH): # If path present, use plugin layout
		add_tool_menu_item("GDSyntaxTags", _on_tool_menu_pressed)

func _exit_tree() -> void:
	if is_instance_valid(window):
		_on_close_requested()
	
	if is_instance_valid(editor_plugin_manager):
		editor_plugin_manager.remove_plugins()
		editor_plugin_manager = null
	
	remove_tool_menu_item("GDSyntaxTags") # won't cause error if it doesn't exist


func _on_tool_menu_pressed():
	if is_instance_valid(window):
		return
	window = Window.new()
	window.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	var display_size = DisplayServer.get_display_safe_area().size
	window.size = Vector2i(1200, display_size.y * 0.8)
	EditorInterface.get_base_control().add_child(window)
	window.close_requested.connect(_on_close_requested)
	var editor = TAG_EDITOR.instantiate()
	window.add_child(editor)
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.close_requested.connect(_on_close_requested)


func _on_close_requested():
	window.queue_free()
	window = null
