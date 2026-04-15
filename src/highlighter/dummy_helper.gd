@tool
extends RefCounted

static var _instances:Dictionary = {}
static var dummy_code_edit: CodeEdit
static var base_gdscript_highlighter: GDScriptSyntaxHighlighter

func _init() -> void:
	_instances[weakref(self)] = true
	set_code_edit()

static func set_code_edit() -> void:
	if not is_instance_valid(base_gdscript_highlighter):
		base_gdscript_highlighter = GDScriptSyntaxHighlighter.new()
	if not is_instance_valid(dummy_code_edit):
		dummy_code_edit = CodeEdit.new()
		dummy_code_edit.highlight_current_line = false
		dummy_code_edit.syntax_highlighter = base_gdscript_highlighter
		var root = Engine.get_main_loop().root
		root.add_child(dummy_code_edit) 
		root.remove_child(dummy_code_edit)

func get_base_highlight(line_idx) -> Dictionary:
	var hl_info: Dictionary = base_gdscript_highlighter.get_line_syntax_highlighting(line_idx)
	return hl_info.duplicate()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_instances.erase(weakref(self))
		
		if _instances.is_empty():
			if is_instance_valid(dummy_code_edit):
				dummy_code_edit.queue_free()
				dummy_code_edit = null
			base_gdscript_highlighter = null
