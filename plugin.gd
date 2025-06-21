@tool
extends EditorPlugin

static var syntax_highlighters:Dictionary = {}

const CONTEXT_MENU = preload("uid://ovp2xnagu2ta")
var context_menu:CONTEXT_MENU

func _enter_tree() -> void:
	add_highlighters()
	
	context_menu = CONTEXT_MENU.new()
	add_context_menu_plugin(context_menu.slot, context_menu)

func _exit_tree() -> void:
	remove_highlighters()
	
	remove_context_menu_plugin(context_menu)


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
