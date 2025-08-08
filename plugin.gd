@tool
extends EditorPlugin

const Utils = preload("res://addons/syntax_plus/src/gdscript/class/syntax_plus_utils.gd")

const EditorPluginManager = Utils.Remote.EditorPluginManager
var editor_plugin_manager:EditorPluginManager

# deps
const EDITOR_PLUGINS_PATH = "res://addons/syntax_plus/src/editor_plugins/syntax_plus_editor_plugins.json" #! dependency
const JSON_PATH = "res://addons/syntax_plus/syntax_plus_tags.json" #! dependency
const PATH_UID_MENU = preload("res://addons/syntax_plus/src/editor_plugins/path_uid_context_menu.gd")
const PATH_UID_LOGIC = preload("res://addons/syntax_plus/src/editor_plugins/path_uid_context_logic.gd")
const SYNTAX_TAG_MENU = preload("res://addons/syntax_plus/src/editor_plugins/syntax_tag_context_menu.gd")
const SYNTAX_TAG_LOGIC = preload("res://addons/syntax_plus/src/editor_plugins/syntax_tag_context_logic.gd")


const MODULAR_BROWSER_PATH = "res://addons/modular_browser"

const TAG_EDITOR = preload("res://addons/syntax_plus/src/ui/tag_editor.tscn") # tag_editor.tscn
var window:Window


func _enter_tree() -> void:
	editor_plugin_manager = EditorPluginManager.new(self, EDITOR_PLUGINS_PATH, true)
	
	if not DirAccess.dir_exists_absolute(MODULAR_BROWSER_PATH): # If path present, use plugin layout
		add_tool_menu_item("SyntaxPlus", _on_tool_menu_pressed)

func _exit_tree() -> void:
	if is_instance_valid(window):
		_on_close_requested()
	
	if is_instance_valid(editor_plugin_manager):
		editor_plugin_manager.remove_plugins()
		editor_plugin_manager = null
	
	remove_tool_menu_item("SyntaxPlus") # won't cause error if it doesn't exist


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







#const PluginLogic = preload("res://addons/syntax_plus/src/syntax_plus_plugin_logic.gd")
#var plugin_logic: PluginLogic
#
#func _enter_tree() -> void:
	#plugin_logic = PluginLogic.new(self)
	#add_child(plugin_logic)
#
#func _exit_tree() -> void:
	#plugin_logic.queue_free()
