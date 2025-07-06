@tool
extends CodeHighlighter

const Utils = preload("uid://bvmvgtxctmgl") #>import utils.gd
const GDHelper = preload("uid://qaydfc8u03fq") #>import gdscript_helper_code.gd
const HighlightHelper = preload("uid://raeyegdbxrem") #>import gdscript_highlight_helper.gd
const TagHighlighter = preload("res://addons/syntax_tags/gdscript/class/tag_highlighter.gd")

const JSON_PATH = "res://addons/syntax_tags/tags.json"

var gd_helper: GDHelper
var highlight_helpers:Array[HighlightHelper] = []
var tag_highlighter:TagHighlighter

var editor_tags:Dictionary = {}
var tagged_data:Dictionary = {}

var current_line_last_state = ""
var last_line_count = 0

var data_overide_flag := false

func _init(data_overide=null) -> void:
	gd_helper = GDHelper.new()
	if data_overide != null:
		data_overide_flag = true
		editor_tags = data_overide
	
	create_highlight_helpers()
	update_tagged_name_list.call_deferred(true)


func read_editor_tags():
	var tag_file_data = Utils.UFile.read_from_json(Utils.JSON_PATH)
	editor_tags = tag_file_data.get("tags", {})

static func load_global_data():
	var tag_file_data = Utils.UFile.read_from_json(Utils.JSON_PATH)
	GDHelper.config = tag_file_data.get("config", {})

func create_highlight_helpers():
	
	for highlight_helper in highlight_helpers:
		highlight_helper = null
	tag_highlighter = null
	tagged_data.clear()
	highlight_helpers.clear()
	var tags = []
	if not data_overide_flag:
		read_editor_tags()
	for tag in editor_tags:
		var data = editor_tags.get(tag)
		var highlighter = HighlightHelper.new(tag, data)
		highlight_helpers.append(highlighter)
		
		tags.append(tag)
	
	tag_highlighter = TagHighlighter.new(tags, editor_tags, GDHelper.config)


func _on_caret_changed():
	var text_edit = get_text_edit()
	current_line_last_state = text_edit.get_line(text_edit.get_caret_line())


func _get_line_syntax_highlighting(line_idx: int) -> Dictionary:
	var text_edit = get_text_edit()
	if not is_instance_valid(GDHelper.dummy_code_edit):
		GDHelper.set_code_edit()
	if not GDHelper.dummy_code_edit.text == text_edit.text:
		_first_line_update()
	
	var current_line_text: String = text_edit.get_line(line_idx)
	
	var hl_info:Dictionary = gd_helper.base_gdscript_highlighter.get_line_syntax_highlighting(line_idx).duplicate()
	
	var needs_sort = false
	for highlight_helper in highlight_helpers:
		var check = highlight_helper.check_line(hl_info, current_line_text)
		hl_info = check[0]
		if not needs_sort:
			needs_sort = check[1]
	
	var check = tag_highlighter.check_line(hl_info, current_line_text)
	hl_info = check[0]
	if not needs_sort:
		needs_sort = check[1]
	
	if needs_sort:
		hl_info = Utils.sort_keys(hl_info)
	
	if line_idx == get_text_edit().get_line_count() - 1:
		clear_highlighting_cache() #forces update.. i think
	
	return hl_info

func _first_line_update() -> void:
	var real_text_edit = get_text_edit()
	if not is_instance_valid(real_text_edit):
		return
	if not GDHelper.dummy_code_edit.text == real_text_edit.text:
		GDHelper.dummy_code_edit.text = real_text_edit.text
		#gd_helper.base_gdscript_highlighter.clear_highlighting_cache()
		GDHelper.default_text_color = EditorInterface.get_editor_settings().get("text_editor/theme/highlighting/text_color")
		update_tagged_name_list()


func update_tagged_name_list(force_build=false) -> void:
	var text_edit_node: CodeEdit = get_text_edit()
	
	var current_line_index = text_edit_node.get_caret_line()
	var current_line_text = text_edit_node.get_line(current_line_index)
	var current_line_count = text_edit_node.get_line_count()
	
	var full_rebuild = false
	if force_build or abs(current_line_count - last_line_count) > 1:
		full_rebuild = true
	
	var new_tagged_data: Dictionary = {}
	for highlight_helper in highlight_helpers:
		var old_data = tagged_data.get(highlight_helper, [])
		new_tagged_data[highlight_helper] = old_data.duplicate()
	
	var current_line_delim = current_line_text.find(Utils.TAG_CHAR) > -1 
	var last_line_delim = current_line_last_state.find(Utils.TAG_CHAR) > -1
	var delim_or_blank = current_line_delim or last_line_delim or current_line_text.strip_edges() == ""
	if delim_or_blank and not full_rebuild: # if not pound sign, no need to check. If blank, check if tag deleted
		for highlight_helper in highlight_helpers:
			var declaration_regex = highlight_helper.declaration_regex
			var _match = declaration_regex.search(current_line_text)
			if _match:
				var tagged_name = _match.get_string(1)
				if not new_tagged_data[highlight_helper].has(tagged_name): # Avoid duplicates
					new_tagged_data[highlight_helper].append(tagged_name)
					break
			else:
				var last_match = declaration_regex.search(current_line_last_state)
				if last_match:
					var tagged_name = last_match.get_string(1)
					new_tagged_data[highlight_helper].erase(tagged_name)
					break
	
	if full_rebuild or tagged_data.hash() != new_tagged_data.hash():
		for highlight_helper in highlight_helpers:
			new_tagged_data[highlight_helper].clear()
		for i in range(current_line_count):
			var line_text = text_edit_node.get_line(i)
			
			for highlight_helper in highlight_helpers:
				var declaration_regex = highlight_helper.declaration_regex
				var _match = declaration_regex.search(line_text)
				if _match:
					var tagged_name = _match.get_string(1)
					if not new_tagged_data[highlight_helper].has(tagged_name): # Avoid duplicates
						new_tagged_data[highlight_helper].append(tagged_name)
		
		tagged_data = new_tagged_data
		for highlight_helper in highlight_helpers:
			highlight_helper.tagged_names = tagged_data[highlight_helper]
			highlight_helper.rebuild_tagged_name_regex()
	
	current_line_last_state = text_edit_node.get_line(current_line_index)
	last_line_count = text_edit_node.get_line_count()


func _clear_highlighting_cache() -> void:
	if is_instance_valid(gd_helper.base_gdscript_highlighter):
		gd_helper.base_gdscript_highlighter.clear_highlighting_cache()
	
	if is_instance_valid(get_text_edit()):
		var text_edit = get_text_edit()
		if not text_edit.caret_changed.is_connected(_on_caret_changed):
			text_edit.caret_changed.connect(_on_caret_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for highlight_helper in highlight_helpers:
			highlight_helper = null
