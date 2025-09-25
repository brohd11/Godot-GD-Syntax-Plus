class_name SyntaxPlus
extends Singleton.RefCount

const SCRIPT = preload("res://addons/syntax_plus/src/syntax_plus_singleton.gd")

static func get_singleton_name() -> String:
	return "SyntaxPlus"

static func get_instance() -> SyntaxPlus:
	return _get_instance(SCRIPT)

static func instance_valid() -> bool:
	return _instance_valid(SCRIPT)

static func register_node(node:Node):
	return _register_node(SCRIPT, node)

static func call_on_ready(callable, print_err:bool=true):
	_call_on_ready(SCRIPT, callable, print_err)

#region Highlight Helper Funcs

var default_text_color:Color
var editor_member_color:Color
var comment_color:Color
var annotation_color:Color
var symbol_color:Color

var single_line_code_edit:CodeEdit
var single_line_gdscript_highlighter: GDScriptSyntaxHighlighter

static func set_default_text_colors():
	var instance = get_instance()
	instance.default_text_color = EditorInterface.get_editor_settings().get("text_editor/theme/highlighting/text_color")
	instance.editor_member_color = EditorInterface.get_editor_settings().get('text_editor/theme/highlighting/member_variable_color')
	instance.comment_color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/comment_color")
	instance.annotation_color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/gdscript/annotation_color")
	instance.symbol_color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/symbol_color")

static func check_code_edit():
	var instance = get_instance()
	if not is_instance_valid(instance.single_line_gdscript_highlighter):
		instance.single_line_gdscript_highlighter = GDScriptSyntaxHighlighter.new()
	if not is_instance_valid(instance.single_line_code_edit):
		instance.single_line_code_edit = CodeEdit.new()
		instance.single_line_code_edit.highlight_current_line = false
		instance.single_line_code_edit.syntax_highlighter = instance.single_line_gdscript_highlighter
		EditorInterface.get_base_control().add_child(instance.single_line_code_edit) 
		EditorInterface.get_base_control().remove_child(instance.single_line_code_edit)

static func get_single_line_highlight(text:String) -> Dictionary:
	var instance = get_instance()
	instance.single_line_code_edit.set_line(0, text)
	var hl_info = instance.single_line_gdscript_highlighter.get_line_syntax_highlighting(0)
	return hl_info.duplicate()


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
