class_name SyntaxPlus
extends Singleton.RefCount

const SCRIPT = preload("res://addons/syntax_plus/src/syntax_plus_singleton.gd")

static func get_singleton_name() -> String:
	return "SyntaxPlus"

static func get_instance() -> SCRIPT:
	return _get_instance(SCRIPT)

static func instance_valid() -> bool:
	return _instance_valid(SCRIPT)

static func register_node(node:Node):
	return _register_node(SCRIPT, node)

static func call_on_ready(callable, print_err:bool=true):
	_call_on_ready(SCRIPT, callable, print_err)

#region Highlight Helper Funcs

static var default_text_color:Color
static var editor_member_color:Color
static var comment_color:Color
static var annotation_color:Color
static var symbol_color:Color

static var single_line_code_edit:CodeEdit
static var single_line_gdscript_highlighter: GDScriptSyntaxHighlighter

static func set_default_text_colors():
	default_text_color = EditorInterface.get_editor_settings().get("text_editor/theme/highlighting/text_color")
	editor_member_color = EditorInterface.get_editor_settings().get('text_editor/theme/highlighting/member_variable_color')
	comment_color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/comment_color")
	annotation_color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/gdscript/annotation_color")
	symbol_color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/symbol_color")

static func check_code_edit():
	if not is_instance_valid(single_line_gdscript_highlighter):
		single_line_gdscript_highlighter = GDScriptSyntaxHighlighter.new()
	if not is_instance_valid(single_line_code_edit):
		single_line_code_edit = CodeEdit.new()
		single_line_code_edit.highlight_current_line = false
		single_line_code_edit.syntax_highlighter = single_line_gdscript_highlighter
		EditorInterface.get_base_control().add_child(single_line_code_edit) 
		EditorInterface.get_base_control().remove_child(single_line_code_edit)

static func get_single_line_highlight(text:String) -> Dictionary:
	single_line_code_edit.set_line(0, text)
	var hl_info = single_line_gdscript_highlighter.get_line_syntax_highlighting(0)
	return hl_info.duplicate()

static func class_name_in_script(word, script):
	var const_map = script.get_script_constant_map()
	if const_map.has(word):
		return const_map.get(word)

#endregion


#region Comment Tags


static func register_comment_tag(tag:String, color:Color=Color.GOLDENROD):
	var instance = get_instance()
	if instance.comment_tag_data.has(tag):
		print("Already have comment tag registered: %s" % tag)
		return
	instance.comment_tag_data[tag] = {"color": color}
	instance.update_comment_tags()

static func unregister_comment_tag(tag:String):
	var instance = get_instance()
	if instance.comment_tag_data.has(tag):
		instance.comment_tag_data.erase(tag)
		instance.update_comment_tags()
		return
	print("Comment tag not registered: %s" % tag)

static func get_comment_tag_data():
	var instance = get_instance()
	return instance.comment_tag_data

static func get_comment_tags():
	var instance = get_instance()
	return instance.comment_tags

#endregion


static func register_highlight_callable(tag:String, callable:Callable, at_start:bool=true):
	var instance = get_instance()
	if instance.highlight_callable_data.has(tag):
		print("Already have highlight callable registered: %s" % tag)
		return
	instance.highlight_callable_data[tag] = {"callable":callable, "at_start":at_start}


static func unregister_highlight_callable(tag:String):
	var instance = get_instance()
	if instance.highlight_callable_data.has(tag):
		instance.highlight_callable_data.erase(tag)
		return
	print("Highlight callable not registered: %s" % tag)

static func get_highlight_callables():
	var instance = get_instance()
	return instance.highlight_callable_data



var comment_tags = []
var comment_tag_data = {}

func update_comment_tags():
	comment_tags = comment_tag_data.keys()


var highlight_callable_data = {}

func _all_unregistered_callback():
	print("Class callback")
	pass

func _init(node) -> void:
	
	pass

static func test():
	var instance = get_instance()
	instance.update_comment_tags()
	print(instance.instance_refs)
