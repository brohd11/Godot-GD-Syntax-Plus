@tool
extends RefCounted

static var _instances:Array[WeakRef] = []
static var dummy_code_edit: CodeEdit
static var base_gdscript_highlighter: GDScriptSyntaxHighlighter

static var default_text_color:Color
static var editor_member_color:Color
static var comment_color:Color
static var annotation_color:Color
static var symbol_color:Color

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
	
	SyntaxPlus.get_instance().check_code_edit()


static func set_default_text_colors():
	var ins = SyntaxPlus.get_instance()
	ins.set_default_text_colors()
	default_text_color = ins.default_text_color
	editor_member_color = ins.editor_member_color
	comment_color = ins.comment_color
	annotation_color = ins.annotation_color
	symbol_color = ins.symbol_color

func get_base_highlight(line_idx) -> Dictionary:
	var hl_info: Dictionary = base_gdscript_highlighter.get_line_syntax_highlighting(line_idx)
	return hl_info.duplicate()




static func sort_comment_tag_info(hl_info:Dictionary, offset=0):
	var key_adjusted_data = {}
	key_adjusted_data[offset] = {"color": comment_color}
	key_adjusted_data[offset + 1] = {"color": annotation_color}
	key_adjusted_data[offset + 2] = {"color": comment_color}
	var hl_keys = hl_info.keys()
	hl_keys.sort()
	for key in hl_keys:
		var new_key = key + offset + 3
		key_adjusted_data[new_key] = hl_info[key]
	
	return key_adjusted_data

static func get_comment_tag_info(current_line_text:String, existing_hl_info=null):
	var tag = current_line_text.get_slice("#!", 1).strip_edges().get_slice(" ", 0).strip_edges()
	var highlight_callables = SyntaxPlus.get_highlight_callables()
	if existing_hl_info == null:
		var callable = _get_comment_tag_hl_info
		if highlight_callables.has(tag):
			var data = highlight_callables.get(tag)
			var at_start = data.get("at_start")
			if at_start:
				callable = data.get("callable")
		
		var hl_info = callable.call(current_line_text)
		hl_info = sort_comment_tag_info(hl_info)
		return hl_info
	
	var callable = _get_comment_tag_hl_info
	if highlight_callables.has(tag):
		var data = highlight_callables.get(tag)
		var at_start = data.get("at_start")
		if not at_start:
			callable = data.get("callable")
	
	var new_hl_info = callable.call(current_line_text)
	
		
	#var new_hl_info = _get_comment_tag_hl_info(current_line_text)
	new_hl_info = sort_comment_tag_info(new_hl_info, current_line_text.get_slice("#!", 0).length())
	existing_hl_info.merge(new_hl_info)
	
	var hl_info = {}
	var existing_keys = existing_hl_info.keys()
	existing_keys.sort()
	for key in existing_keys:
		hl_info[key] = existing_hl_info[key]
	
	return hl_info

static func _class_name_in_script(word, script):
	var const_map = script.get_script_constant_map()
	if const_map.has(word):
		return const_map.get(word)


static func _get_comment_tag_hl_info(current_line_text):
	var comment_tags = SyntaxPlus.get_comment_tags()
	var comment_tag_data = SyntaxPlus.get_comment_tag_data()
	var temp_hl_info:Dictionary = {}
	var comment_tag_text = current_line_text.get_slice("#!", 1).replace(".", " ").strip_edges()
	var new_hl_info = SyntaxPlus.get_instance().get_single_line_highlight(comment_tag_text)
	var words = comment_tag_text.split(" ")
	for word in words:
		if word in comment_tags:
			var idx = comment_tag_text.find(word) - 1
			temp_hl_info[idx] = comment_tag_data.get(word)
			idx += 1
			while idx < word.length():
				temp_hl_info.erase(idx)
				idx += 1
	return temp_hl_info

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
