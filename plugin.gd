@tool
extends EditorPlugin

const Utils = preload("res://addons/syntax_plus/src/gdscript/class/syntax_plus_utils.gd")
const UtilsRemote = preload("res://addons/syntax_plus/src/gdscript/class/syntax_plus_remote.gd")

const DockManager = UtilsRemote.DockManager
var dock_manager:DockManager

const EditorPluginManager = Utils.Remote.EditorPluginManager
var editor_plugin_manager:EditorPluginManager

const GDScriptSyntaxPlus = preload("res://addons/syntax_plus/src/gdscript/editor/gdscript_syntax_plus.gd")

# deps
const JSON_PATH = "res://addons/syntax_plus/syntax_plus_tags.json" #! dependency
const CONTEXT_PLUGINS = [
	"res://addons/syntax_plus/src/editor_plugins/path_uid_context_menu.gd", #! dependency
	"res://addons/syntax_plus/src/editor_plugins/syntax_tag_context_menu.gd" #! dependency
]
const SYNTAX_HIGHLIGHTERS = [
	"res://addons/syntax_plus/src/gdscript/editor/gdscript_syntax_plus.gd" #! dependency
]

const MODULAR_BROWSER_PATH = "res://addons/modular_browser"

const TAG_EDITOR = preload("res://addons/syntax_plus/src/ui/tag_editor.tscn") # tag_editor.tscn

var window:Window

func _get_plugin_name() -> String:
	return "Syntax Plus"
func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("SyntaxHighlighter", &"EditorIcons")
func _has_main_screen() -> bool:
	return true

func _enable_plugin() -> void:
	Utils.initial_set_editor_settings()

func _enter_tree() -> void:
	DockManager.hide_main_screen_button(self)
	
	editor_plugin_manager = EditorPluginManager.new(self)
	editor_plugin_manager.context_menu_plugin_paths = CONTEXT_PLUGINS
	editor_plugin_manager.syntax_highlighter_paths = SYNTAX_HIGHLIGHTERS
	editor_plugin_manager.add_plugins()
	
	EditorInterface.get_script_editor().editor_script_changed.connect(_on_editor_script_changed, 1)
	
	#if not DirAccess.dir_exists_absolute(MODULAR_BROWSER_PATH): # If path present, use plugin layout
	add_tool_menu_item("SyntaxPlus", _on_tool_menu_pressed)

func _exit_tree() -> void:
	if is_instance_valid(editor_plugin_manager):
		editor_plugin_manager.remove_plugins()
		editor_plugin_manager = null
	
	if is_instance_valid(dock_manager):
		dock_manager.clean_up()
	remove_tool_menu_item("SyntaxPlus") # won't cause error if it doesn't exist


func _on_tool_menu_pressed():
	dock_manager = DockManager.new(self, TAG_EDITOR, DockManager.Slot.MAIN_SCREEN, true, null, false)
	dock_manager.set_default_window_size(Vector2i(DisplayServer.screen_get_size() * 0.8))
	dock_manager.post_init()


func _on_editor_script_changed(script:Script) -> void:
	if script == null:
		return
	if script.resource_path.get_extension() != "gd":
		return
	if EditorInterface.get_script_editor().get_current_editor() == null:
		return
	if Utils._get_editor_setting(Utils.Config.set_as_default_highlighter):
		var base_ed = EditorInterface.get_script_editor().get_current_editor().get_base_editor()
		if base_ed.syntax_highlighter is not GDScriptSyntaxPlus:
			Utils.set_script_highlighter()
