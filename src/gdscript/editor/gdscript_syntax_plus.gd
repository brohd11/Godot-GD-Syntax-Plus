@tool
extends EditorSyntaxHighlighter

const PLUGIN_EXPORTED = false

const Utils = preload("res://addons/syntax_plus/src/gdscript/class/syntax_plus_utils.gd") #>import utils.gd
const GDHelper = preload("res://addons/syntax_plus/src/gdscript/editor/gdscript_helper.gd") #>import gdscript_helper.gd
const HighlightHelper = preload("res://addons/syntax_plus/src/gdscript/class/gdscript_highlight_helper.gd") #>import gdscript_highlight_helper.gd
const MemberHighlighter = preload("res://addons/syntax_plus/src/gdscript/class/gdscript_member_highlighter.gd")
const TagHighlighter = preload("res://addons/syntax_plus/src/gdscript/class/tag_highlighter.gd") #>import tag_highlighter.gd

var hl_info_cache:Dictionary[int,Dictionary]

var gd_helper: GDHelper
var highlight_helpers:Array[HighlightHelper] = []
var tag_highlighter:TagHighlighter

var member_highlighter:MemberHighlighter

static var editor_tags:Dictionary = {}
var tagged_data:Dictionary = {}

var current_line_last_state = ""
var last_line_count = 0

var lines_highlighting = false
var init_scan_done:= false


func _get_name() -> String:
	return "SyntaxPlus"

func _init() -> void:
	gd_helper = GDHelper.new()
	EditorInterface.get_script_editor().editor_script_changed.connect(_on_editor_script_changed)
	create_highlight_helpers()
	


func create_highlight_helpers():
	init_scan_done = false ## NOT REDUNDANT
	for highlight_helper in highlight_helpers:
		highlight_helper = null
	tag_highlighter = null
	tagged_data.clear()
	highlight_helpers.clear()
	var tags = []
	read_editor_tags()
	load_global_data()
	for tag in editor_tags:
		var data = editor_tags.get(tag)
		var highlighter = HighlightHelper.new(tag, data)
		highlight_helpers.append(highlighter)
		tags.append(tag)
	
	if GDHelper.config.get(Utils.Config.const_enable):
		var const_tag_highlighter = HighlightHelper.new("=CONST_HL",Utils.get_const_hl_data())
		highlight_helpers.append(const_tag_highlighter)
	if GDHelper.config.get(Utils.Config.pascal_enable, false):
		var class_tag_highlighter = HighlightHelper.new("=CLASS_HL",Utils.get_pascal_hl_data())
		highlight_helpers.append(class_tag_highlighter)
	if GDHelper.config.get(Utils.Config.onready_enable):
		var onready_tag_highlighter = HighlightHelper.new("=ONREADY_HL", Utils.get_onready_hl_data())
		highlight_helpers.append(onready_tag_highlighter)
	
	if GDHelper.config.get(Utils.Config.member_enable):
		member_highlighter = MemberHighlighter.new("=MEMBER_HL",Utils.get_member_hl_data())
	tag_highlighter = TagHighlighter.new(tags, editor_tags, GDHelper.config)


static func read_editor_tags():
	editor_tags = Utils.get_tags_data()

static func load_global_data():
	GDHelper.config = Utils.get_editor_config()

func _on_editor_script_changed(new_script:Script):
	var text_edit = get_text_edit()
	if not is_instance_valid(text_edit):
		return
	
	var script_editor = text_edit.get_parent()
	for i in range(5):
		if script_editor != null:
			if script_editor.get_class() == "ScriptTextEditor":
				break
			script_editor = script_editor.get_parent()
		else: return # this is called on all instance, return if cant get to script ed
	
	if script_editor == EditorInterface.get_script_editor().get_current_editor():
		if not get_text_edit(): # double check for closing scripts
			return
		set_class_member_names()
		GDHelper.set_default_text_colors()
		GDHelper.set_code_edit()
		init_scan_done = false

func set_class_member_names():
	if member_highlighter:
		member_highlighter.member_highlight_mode = Utils._get_editor_setting(Utils.Config.member_highlight_mode)
		member_highlighter.check_class_valid()

func force_class_member_rebuild():
	if member_highlighter:
		member_highlighter.force_class_member_rebuild()

func _on_caret_changed():
	var text_edit = get_text_edit()
	current_line_last_state = text_edit.get_line(text_edit.get_caret_line())


func _get_line_syntax_highlighting(line_idx: int) -> Dictionary:
	var text_edit = get_text_edit() 
	var current_line_text: String = text_edit.get_line(line_idx)
	if not init_scan_done:
		init_scan_done = true
		GDHelper.set_code_edit()
		GDHelper.dummy_code_edit.text = get_text_edit().text
		set_class_member_names()
		update_tagged_name_list(true)
	
	if GDHelper.dummy_code_edit.get_line(line_idx) != current_line_text:
		if line_idx >= GDHelper.dummy_code_edit.get_line_count():
			check_newline_buffer()
		GDHelper.dummy_code_edit.set_line(line_idx, current_line_text)
		if line_idx == text_edit.get_caret_line():
			update_tagged_name_list()
	
	var comment_tag_index = current_line_text.find("#!")
	if comment_tag_index == 0:
		if current_line_text.find('"#!') == -1:
			return GDHelper.get_comment_tag_info(current_line_text)
	
	## Not 100% sure duplicate is neces
	var hl_info:Dictionary = gd_helper.base_gdscript_highlighter.get_line_syntax_highlighting(line_idx)
	
	
	
	
	## clear signal member color, set via regex
	var stripped_line_text = current_line_text.strip_edges()
	if stripped_line_text.begins_with("signal "):
		hl_info[current_line_text.find("signal ") + 7] = {"color": GDHelper.default_text_color}
	##
	
	## Overide member access color
	if GDHelper.config.get(Utils.Config.member_access_enable):
		for key in hl_info.keys():
			var data = hl_info.get(key)
			var og_color = data.get("color")
			if og_color == GDHelper.editor_member_color:
				hl_info[key]["color"] = GDHelper.config.get(Utils.Config.member_access_color)
	##
	
	## Sort keys, necessary
	var needs_sort = false
	for highlight_helper in highlight_helpers: 
		var check = highlight_helper.check_line(hl_info, current_line_text)
		hl_info = check[0]
		if not needs_sort:
			needs_sort = check[1]
	##
	
	## Member check
	if member_highlighter:
		var member_check = member_highlighter.check_line(hl_info, current_line_text)
		hl_info = member_check[0]
		if not needs_sort:
			needs_sort = member_check[1]
	##
	
	## Highlight tags
	var tag_check = tag_highlighter.check_line(hl_info, current_line_text)
	hl_info = tag_check[0]
	if not needs_sort:
		needs_sort = tag_check[1]
	##
	
	if comment_tag_index != -1:
		if current_line_text.find('"#!') == -1:
			hl_info = GDHelper.get_comment_tag_info(current_line_text, hl_info)
	
	if needs_sort:
		hl_info = Utils.sort_keys(hl_info)
	return hl_info


func update_tagged_name_list(force_build=false) -> void:
	var text_edit_node: CodeEdit = get_text_edit()
	var current_line_index = text_edit_node.get_caret_line()
	var current_line_text = text_edit_node.get_line(current_line_index)
	var current_line_count = text_edit_node.get_line_count()
	
	var full_rebuild = force_build
	if abs(current_line_count - last_line_count) > 1:
		full_rebuild = true ## NOT SURE OF THIS CHECK
	
	## new copy of data to compare to old if tagged removed or added to current line
	var new_tagged_data: Dictionary = {}
	for highlight_helper in highlight_helpers:
		var old_data = tagged_data.get(highlight_helper, {})
		new_tagged_data[highlight_helper] = old_data.duplicate()
	if member_highlighter:
		var old_member_data = tagged_data.get(member_highlighter, {})
		new_tagged_data[member_highlighter] = old_member_data.duplicate()
	##
	
	## if flags found, check for changes in current line
	var check = Utils.check_line_for_rebuild(current_line_text, current_line_last_state)
	if check and not full_rebuild:
		var found_name = false
		for highlight_helper in highlight_helpers:
			var declaration_regex = highlight_helper.declaration_regex
			var _match = declaration_regex.search(current_line_text)
			if _match:
				var tagged_name = _match.get_string(1)
				new_tagged_data[highlight_helper][tagged_name] = true
				found_name = true
				break # break? only 1 per line?
			else:
				var last_match = declaration_regex.search(current_line_last_state)
				if last_match:
					var tagged_name = last_match.get_string(1)
					new_tagged_data[highlight_helper].erase(tagged_name)
					found_name = true
					break
		
		if member_highlighter and not found_name:
			var _match = member_highlighter.declaration_regex.search(current_line_text)
			if _match:
				var tagged_name = _match.get_string(1)
				new_tagged_data[member_highlighter][tagged_name] = true
			
			var last_match = member_highlighter.declaration_regex.search(current_line_last_state)
			if last_match:
				var tagged_name = last_match.get_string(1)
				new_tagged_data[member_highlighter].erase(tagged_name)
	##
	
	## Full scan of doc for valid highlights
	if full_rebuild or tagged_data.hash() != new_tagged_data.hash():
		for highlight_helper in highlight_helpers:
			new_tagged_data[highlight_helper].clear()
			highlight_helper.tagged_names.clear() 
		if member_highlighter:
			member_highlighter.script_member_names.clear()
		# line by line check with regex for pattern, const = CONST, etc
		for i in range(current_line_count):
			var line_names_found = [] # anything not in arary may be added to member regex
			var line_text = text_edit_node.get_line(i)
			for highlight_helper in highlight_helpers:
				var declaration_regex = highlight_helper.declaration_regex
				var _match = declaration_regex.search(line_text)
				if _match:
					var tagged_name = _match.get_string(1)
					new_tagged_data[highlight_helper][tagged_name] = true
					highlight_helper.tagged_names[tagged_name] = true
					line_names_found.append(tagged_name)
			
			if member_highlighter:
				var _match = member_highlighter.declaration_regex.search(line_text)
				if _match:
					var tagged_name = _match.get_string(1)
					if not tagged_name in line_names_found:
						new_tagged_data[member_highlighter][tagged_name] = true
						member_highlighter.script_member_names[tagged_name] = true
		#
		tagged_data = new_tagged_data
		for highlight_helper in highlight_helpers:
			#var t2 = Time.get_ticks_usec()
			highlight_helper.rebuild_tagged_name_regex()
			#if not PLUGIN_EXPORTED: print("build regex ", Time.get_ticks_usec() - t2," ", highlight_helper.highlight_tag)
		
		if member_highlighter:
			#var t2 = Time.get_ticks_usec()
			member_highlighter.rebuild_script_member_regex()
			#if not PLUGIN_EXPORTED: print("build member regex ", Time.get_ticks_usec() - t2)
	##
	
	## Set state
	current_line_last_state = text_edit_node.get_line(current_line_index)
	last_line_count = text_edit_node.get_line_count()
	
	check_newline_buffer()
	
	#update_cache.call_deferred() ## Needed?


func check_newline_buffer():
	var text_edit = get_text_edit()
	var line_count = text_edit.get_line_count()
	var dummy_line_count = GDHelper.dummy_code_edit.get_line_count()
	var buffer_health = dummy_line_count - line_count
	var buffer_size = 30
	if buffer_health < 0:
		var lines_needed = -buffer_health + buffer_size
		var new_lines = "\n".repeat(lines_needed)
		GDHelper.dummy_code_edit.text += new_lines
	elif buffer_health > buffer_size * 2:
		GDHelper.dummy_code_edit.text = text_edit.text
	elif buffer_health < 15:
		GDHelper.dummy_code_edit.text += "\n".repeat(buffer_size)


func _clear_highlighting_cache() -> void: #>deb
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
