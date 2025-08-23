@tool
extends RefCounted

static var _instances:Array[WeakRef] = []
static var dummy_code_edit: CodeEdit
static var base_gdscript_highlighter: GDScriptSyntaxHighlighter

static var default_text_color:Color
static var editor_member_color:Color

static var config:Dictionary = {}

func _init() -> void:
	_instances.append(weakref(self))
	set_code_edit()

static func set_code_edit() -> void:
	if not is_instance_valid(base_gdscript_highlighter):
		base_gdscript_highlighter = GDScriptSyntaxHighlighter.new()
	if not is_instance_valid(dummy_code_edit):
		dummy_code_edit = CodeEdit.new()
		dummy_code_edit.highlight_current_line = false
		dummy_code_edit.syntax_highlighter = base_gdscript_highlighter
		EditorInterface.get_base_control().add_child(dummy_code_edit) 
		EditorInterface.get_base_control().remove_child(dummy_code_edit)
		set_default_text_colors()

static func set_default_text_colors():
	default_text_color = EditorInterface.get_editor_settings().get("text_editor/theme/highlighting/text_color")
	editor_member_color = EditorInterface.get_editor_settings().get('text_editor/theme/highlighting/member_variable_color')

func get_base_highlight(line_idx) -> Dictionary:
	var hl_info: Dictionary = base_gdscript_highlighter.get_line_syntax_highlighting(line_idx)
	return hl_info.duplicate()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for ref in _instances:
			if ref.get_ref() == self:
				_instances.erase(ref)
				break
		
		if _instances.is_empty():
			if is_instance_valid(dummy_code_edit):
				dummy_code_edit.queue_free()
				dummy_code_edit = null
			base_gdscript_highlighter = null

