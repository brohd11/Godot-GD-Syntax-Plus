@tool
extends EditorPlugin

static var syntax_highlighters:Dictionary = {}

const TAG_EDITOR = preload("res://addons/syntax_tags/ui/tag_editor.tscn")
var window:Window

const CONTEXT_MENU = preload("uid://ovp2xnagu2ta")
var context_menu:CONTEXT_MENU

func _enter_tree() -> void:
	add_highlighters()
	
	context_menu = CONTEXT_MENU.new()
	add_context_menu_plugin(context_menu.slot, context_menu)
	
	add_tool_menu_item("GDSyntaxTags", _on_tool_menu_pressed)

func _exit_tree() -> void:
	remove_highlighters()
	
	remove_context_menu_plugin(context_menu)
	
	remove_tool_menu_item("GDSyntaxTags")


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

#region Add/Remove Logic

static func add_highlighters():
	for key in HIGHLIGHTERS:
		var script = HIGHLIGHTERS.get(key)
		var highlighter = script.new()
		EditorInterface.get_script_editor().register_syntax_highlighter(highlighter)
		syntax_highlighters[key] = highlighter

static func remove_highlighters():
	for key in syntax_highlighters:
		var highlighter = syntax_highlighters.get(key)
		EditorInterface.get_script_editor().unregister_syntax_highlighter(highlighter)

#endregion

# Add inspector plugins here.
const HIGHLIGHTERS = {
	"GDSynTags": preload("uid://c4om4mori5lad") # res://addons/syntax_tags/gdscript/class/gdscript_tags.gd
}
