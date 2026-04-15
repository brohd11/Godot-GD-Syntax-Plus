# HL
const PLUGIN_EXPORTED = false

const GDScriptParser = ALibRuntime.Utils.UGDScript.Parser

const Utils = preload("res://addons/syntax_plus/src/gdscript/class/syntax_plus_utils.gd")
const UClassDetail = Utils.UClassDetail

const DummyHelper = preload("res://addons/syntax_plus/src/highlighter/dummy_helper.gd")
const HighlightHelper = preload("res://addons/syntax_plus/src/highlighter/highlight_helper.gd")
const TagHighlighter = preload("res://addons/syntax_plus/src/gdscript/class/tag_highlighter.gd")

static var default_text_color:Color
static var editor_member_color:Color

static var const_color:Color
static var pascal_color:Color
static var member_color:Color
static var member_access_color:Color
static var inh_member_color:Color
static var base_type_member_color:Color
static var inner_class_member_color:Color

static var const_enable:bool
static var pascal_enable:bool
static var member_enable:bool
static var member_access_enable:bool
static var inh_member_enable:bool
static var base_type_member_enable:bool
static var inner_class_member_enable:bool

static var tag_color:Color
static var tag_enable:bool
static var editor_tags:Dictionary = {}

static var _const_regex:RegEx
static var _pascal_regex:RegEx

var _gdscript_parser:WeakRef
var gdscript_parser:GDScriptParser # maybe could have it's own?
var script_resource:GDScript

var dummy_helper:DummyHelper

var highlight_helpers:Array[HighlightHelper] = []
var script_member_highlighters:Array[HighlightHelper] = []

var const_highlighter:HighlightHelper
var pascal_highlighter:HighlightHelper
var member_highlighter:HighlightHelper
var inherited_member_highlighter:HighlightHelper
var class_member_highlighter:HighlightHelper
var inner_class_member_highlighter:HighlightHelper

var tag_highlighter:TagHighlighter

var _text_edit:CodeEdit
var cache_dirty:= true
var _temp_member_dict:= {}

var tagged_data:Dictionary = {}

var current_line_last_state = ""
var last_line_count = 0

var init_scan_done:= false

var comment_tag_prefixes:= []

signal scanning_tags


func _init() -> void:
	dummy_helper = DummyHelper.new()
	create_highlight_helpers()

func set_text_edit(text_edit:TextEdit):
	_text_edit = text_edit

func get_text_edit():
	return _text_edit

func set_gdscript_parser(parser:GDScriptParser):
	_gdscript_parser = weakref(parser)

func get_gdscript_parser() -> GDScriptParser:
	return _gdscript_parser.get_ref()


func create_highlight_helpers():
	init_scan_done = false #^r NOT REDUNDANT
	
	for highlight_helper in highlight_helpers:
		highlight_helper = null
	tag_highlighter = null # clear when reseting
	tagged_data.clear()
	highlight_helpers.clear()
	var tags = []
	for tag in editor_tags:
		var data = editor_tags.get(tag)
		var highlighter = HighlightHelper.new(data.get("color"), tag, data)
		highlight_helpers.append(highlighter)
		tags.append(tag)
	
	script_member_highlighters.clear()
	if const_enable:
		const_highlighter = HighlightHelper.new(const_color)
		script_member_highlighters.append(const_highlighter)
		
	if pascal_enable:
		pascal_highlighter = HighlightHelper.new(pascal_color)
		script_member_highlighters.append(pascal_highlighter)
	
	if member_enable:
		member_highlighter = HighlightHelper.new(member_color, "=MEMBER_HL")
		script_member_highlighters.append(member_highlighter)
		
	if inh_member_enable:
		inherited_member_highlighter = HighlightHelper.new(inh_member_color)
		script_member_highlighters.append(inherited_member_highlighter)
		
	if base_type_member_enable:
		class_member_highlighter = HighlightHelper.new(base_type_member_color)
		script_member_highlighters.append(class_member_highlighter)
	
	if inner_class_member_enable:
		inner_class_member_highlighter = HighlightHelper.new(inner_class_member_color)
		script_member_highlighters.append(inner_class_member_highlighter)
	
	tag_highlighter = TagHighlighter.new(tags, editor_tags)
	tag_highlighter.tag_enabled = tag_enable
	tag_highlighter.highlight_color = tag_color


func _on_caret_changed():
	var text_edit = get_text_edit()
	current_line_last_state = text_edit.get_line(text_edit.get_caret_line())


func get_line_syntax_highlighting(line_idx: int) -> Dictionary:
	var text_edit = get_text_edit() as CodeEdit
	#if not is_instance_valid(text_edit):
		#return {}
	var current_line_text: String = text_edit.get_line(line_idx)
	if not init_scan_done:
		init_scan_done = true
		scanning_tags.emit()
		DummyHelper.set_code_edit()
		DummyHelper.dummy_code_edit.text = get_text_edit().text
		update_tagged_name_list(true)
	
	if DummyHelper.dummy_code_edit.get_line(line_idx) != current_line_text:
		if line_idx >= DummyHelper.dummy_code_edit.get_line_count():
			check_newline_buffer()
		DummyHelper.dummy_code_edit.set_line(line_idx, current_line_text)
		if line_idx == text_edit.get_caret_line():
			update_tagged_name_list()
	
	#^ is comment in string
	var comment_index = current_line_text.find("#")
	while comment_index != -1:
		if text_edit.is_in_string(line_idx, comment_index) == -1:
			break
		comment_index = current_line_text.find("#", comment_index + 1)
	#^
	
	#^ comment tag
	var comment_tag_prefix = ""
	var comment_tag_index = -1
	if comment_index != -1:
		var comment_substr = current_line_text.substr(comment_index)
		for prefix in comment_tag_prefixes:
			if comment_substr.find(prefix) > -1:
				comment_tag_index = current_line_text.find(prefix)
				comment_tag_prefix = prefix
				if comment_index == 0:
					return SyntaxPlusSingleton.HLInfo.get_comment_tag_info(text_edit, current_line_text, line_idx, comment_tag_prefix, comment_tag_index)
				break
	
	#^ Not 100% sure duplicate is neces
	var hl_info:Dictionary = dummy_helper.base_gdscript_highlighter.get_line_syntax_highlighting(line_idx)
	
	#^ clear signal member color, set via regex
	var stripped_line_text = current_line_text.strip_edges()
	if stripped_line_text.begins_with("signal "):
		hl_info[current_line_text.find("signal ") + 7] = {"color": default_text_color}
	#^
	
	#^ Overide member access color
	if member_access_enable:
		for key in hl_info.keys():
			var data = hl_info.get(key)
			var og_color = data.get("color")
			if og_color == editor_member_color:
				hl_info[key]["color"] = member_access_color
	#^
	
	#^ Sort keys, necessary
	var needs_sort = false
	for highlight_helper in highlight_helpers: 
		var check = highlight_helper.check_line(hl_info, current_line_text)
		hl_info = check[0]
		if not needs_sort:
			needs_sort = check[1]
	#^
	
	#^ Member check
	for highlighter in script_member_highlighters:
		var member_check = highlighter.check_line(hl_info, current_line_text)
		hl_info = member_check[0]
		if not needs_sort:
			needs_sort = member_check[1]
	#^
	
	#^ Highlight tags
	var tag_check = tag_highlighter.check_line(hl_info, current_line_text)
	hl_info = tag_check[0]
	if not needs_sort:
		needs_sort = tag_check[1]
	#^
	
	if comment_tag_prefix != "":
		hl_info = SyntaxPlusSingleton.HLInfo.get_comment_tag_info(text_edit, current_line_text, line_idx, comment_tag_prefix, comment_tag_index, hl_info)
	
	if needs_sort:
		hl_info = Utils.sort_keys(hl_info)
	return hl_info



func update_tagged_name_list(force_build=false) -> void:
	_initialize_regexes()
	var t = ALibRuntime.Utils.UProfile.TimeFunction.new("UPDATE TAGGED NEW")
	var text_edit_node: CodeEdit = get_text_edit()
	if not text_edit_node.caret_changed.is_connected(_on_caret_changed):
		text_edit_node.caret_changed.connect(_on_caret_changed)
	
	var current_line_index = text_edit_node.get_caret_line()
	var current_line_text = text_edit_node.get_line(current_line_index)
	var current_line_count = text_edit_node.get_line_count()
	
	var full_rebuild = force_build
	#if abs(current_line_count - last_line_count) > 1:
		#full_rebuild = true ## NOT SURE OF THIS CHECK
	
	#^ new copy of data to compare to old if tagged removed or added to current line
	var new_tagged_data: Dictionary = {}
	for highlight_helper in highlight_helpers:
		var old_data = tagged_data.get(highlight_helper, {})
		new_tagged_data[highlight_helper] = old_data.duplicate()
	
	#^
	
	
	#^ if flags found, check for changes in current line
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
			var _match = member_highlighter.declaration_regex.search(current_line_text) #>debu
			if _match == null:
				_temp_member_dict.clear()
			else:
				_update_current_line_dec(_match.get_string(0), true)
			
			var last_match = member_highlighter.declaration_regex.search(current_line_last_state)
			if last_match:
				var _last_match_dec = last_match.get_string(0)
				if _match != null and _match.get_string(0) != _last_match_dec:
					_update_current_line_dec(_last_match_dec, false)
	#^
	
	prints("UPDATE FULL::", full_rebuild, tagged_data.hash() != new_tagged_data.hash())
	#^ Full scan of doc for valid highlights
	if full_rebuild or tagged_data.hash() != new_tagged_data.hash():
		print("HAS TAG", highlight_helpers)
		var has_tag = false
		for highlight_helper in highlight_helpers:
			new_tagged_data[highlight_helper].clear()
			#if not has_tag:
				#has_tag = text_edit_node.text.contains(Utils.TAG_CHAR + highlight_helper.highlight_tag)
				#print("HAS TAG::", has_tag, "::", highlight_helper.highlight_tag)
		
		for i in range(current_line_count):
			var line_names_found = [] # anything not in arary may be added to member regex
			var line_text = text_edit_node.get_line(i)
			for highlight_helper in highlight_helpers:
				var declaration_regex = highlight_helper.declaration_regex
				var _match = declaration_regex.search(line_text) #>debu
				if _match:
					var tagged_name = _match.get_string(1)
					new_tagged_data[highlight_helper][tagged_name] = true
					line_names_found.append(tagged_name)
		
		tagged_data = new_tagged_data
		
		var has_changed_tag = false
		for highlight_helper in highlight_helpers:
			var highlight_data = new_tagged_data[highlight_helper]
			print("TAG CHANGED::",highlight_helper.highlight_words.keys(), highlight_data.keys())
			var chg = highlight_helper.set_highlight_words(highlight_data)
			if chg:
				has_changed_tag = true
		
		
		
		if has_changed_tag: # fairly slow, would be nice to check if needed, any instances of word above
			invalidate_all() # for this PC it's not really a big deal...
	
	#update_class_members()
	#^
	
	#^ Set state
	current_line_last_state = text_edit_node.get_line(current_line_index)
	last_line_count = text_edit_node.get_line_count()
	t.stop()
	check_newline_buffer()
	
	
	#update_cache.call_deferred() ## Needed?


func _update_current_line_dec(current_line_dec:String, add:bool):
	var dec_name = current_line_dec.get_slice(" ", 1).strip_edges()
	if not add and not _temp_member_dict.has(dec_name):
		return
	
	var target_hl = member_highlighter
	if _is_static_declaration(current_line_dec):
		if _is_const(dec_name):
			target_hl = const_highlighter
		elif _is_pascal(dec_name):
			target_hl = pascal_highlighter
	
	var word_dict = target_hl.highlight_words.duplicate()
	if add:
		#if word_dict.has(dec_name):
			#return
		word_dict[dec_name] = true
		_temp_member_dict[dec_name] = true
	else:
		word_dict.erase(dec_name)
		_temp_member_dict.erase(dec_name)
	
	target_hl.set_highlight_words(word_dict)



func update_class_members(allow_invalidate:=false):
	var t = ALibRuntime.Utils.UProfile.TimeFunction.new("UPDATE CLASS MEMBERS")
	if not is_instance_valid(gdscript_parser):
		gdscript_parser = GDScriptParser.new()
		gdscript_parser.set_current_script(script_resource)
		gdscript_parser.set_code_edit(get_text_edit())
		gdscript_parser.set_parser_cache_size(0)
	
	print("CACHE DIRTY::", gdscript_parser.get_code_edit_parser().cache_dirty)
	if not gdscript_parser.get_code_edit_parser().cache_dirty:
		print("EARLY EXIT")
		return
	
	gdscript_parser.parse()
	print(gdscript_parser)
	print("UPDATING CLASS MEMBERS")
	_initialize_regexes()
	#var parser = get_gdscript_parser()
	var parser = gdscript_parser
	
	var new_const_words:= {}
	var new_pasc_words:= {}
	var new_member_words:= {}
	var new_inh_member_words:= {}
	var inner_class_member_words:= {}
	
	print("UPDATE PARSER::", parser.get_current_script())
	print(get_text_edit().get_line(0))
	
	var main_class_obj = parser.get_class_object() as GDScriptParser.ParserClass
	for m in main_class_obj.get_inherited_members():
		new_inh_member_words[m] = true
	
	var i_chg := inherited_member_highlighter.set_highlight_words(new_inh_member_words)
	
	var new_base_type_members = UClassDetail.get_members_of_base_type(main_class_obj.script_base_type)
	var cl_chg := class_member_highlighter.set_highlight_words(new_base_type_members)
	
	
	for access_name in parser.get_classes():
		var class_obj = parser.get_class_object(access_name) as GDScriptParser.ParserClass
		
		for c:String in class_obj.constants:
			_check_word(c, new_const_words, new_pasc_words, new_member_words)
		
		for ic:String in class_obj.inner_classes:
			_check_word(ic, new_const_words, new_pasc_words, new_member_words)
		
		if access_name.is_empty():
			for m:String in class_obj.members:
				new_member_words[m] = true
		else:
			for m:String in class_obj.members:
				inner_class_member_words[m] = true
	
	
	#print(member_highlighter.highlight_words.size())
	#print(member_highlighter.highlight_words.keys())
	#print(new_member_words.size())
	#print(new_member_words.keys())
	
	var c_chg := const_highlighter.set_highlight_words(new_const_words)
	var p_chg := pascal_highlighter.set_highlight_words(new_pasc_words)
	var m_chg := member_highlighter.set_highlight_words(new_member_words)
	var ic_chg := inner_class_member_highlighter.set_highlight_words(inner_class_member_words)
	if allow_invalidate and (i_chg or cl_chg or c_chg or p_chg or m_chg or ic_chg):
		prints("INVAL ON CLASS::",i_chg , cl_chg , c_chg , p_chg , m_chg , ic_chg)
		invalidate_all()
	
	t.stop()



func check_newline_buffer():
	var text_edit = get_text_edit()
	var line_count = text_edit.get_line_count()
	var dummy_line_count = DummyHelper.dummy_code_edit.get_line_count()
	var buffer_health = dummy_line_count - line_count
	var buffer_size = 30
	if buffer_health < 0:
		var lines_needed = -buffer_health + buffer_size
		var new_lines = "\n".repeat(lines_needed)
		DummyHelper.dummy_code_edit.text += new_lines
	elif buffer_health > buffer_size * 2:
		DummyHelper.dummy_code_edit.text = text_edit.text
	elif buffer_health < 15:
		DummyHelper.dummy_code_edit.text += "\n".repeat(buffer_size)


func clear_highlighting_cache() -> void:
	if is_instance_valid(dummy_helper.base_gdscript_highlighter): # do I need this?
		dummy_helper.base_gdscript_highlighter.clear_highlighting_cache()
	
	return
	if is_instance_valid(get_text_edit()):
		var text_edit = get_text_edit()
		if not text_edit.caret_changed.is_connected(_on_caret_changed):
			text_edit.caret_changed.connect(_on_caret_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for highlight_helper in highlight_helpers:
			highlight_helper = null

func _is_static_declaration(text:String):
	return text.begins_with("const ") or text.begins_with("class ") or text.begins_with("enum ")

func _check_word(word:String, const_dict:Dictionary, pasc_dict:Dictionary, member_dict:Dictionary):
	if _is_const(word):
		const_dict[word] = true
	elif _is_pascal(word):
		pasc_dict[word] = true
	else:
		member_dict[word] = true

func _is_const(text:String):
	return _const_regex.search(text) != null

func _is_pascal(text:String):
	return _pascal_regex.search(text) != null

func _initialize_regexes():
	if not is_instance_valid(_const_regex):
		_const_regex = RegEx.new()
		_const_regex.compile("\\b([A-Z][A-Z_0-9]*)\\b")
	if not is_instance_valid(_pascal_regex):
		_pascal_regex = RegEx.new()
		_pascal_regex.compile("\\b([A-Z]\\w*[a-z]\\w*)\\b")
		


func invalidate_all():
	_invalidate_all.call_deferred()

func _invalidate_all():
	#clear_highlighting_cache()
	#return
	#init_scan_done = false # should be good to ignore this now that setting dummy_code_edit
	var text_edit = get_text_edit()
	var text_changed_signal_list = text_edit.get_signal_connection_list("text_changed")
	for data in text_changed_signal_list:
		var callable = data.get("callable")
		text_edit.text_changed.disconnect(callable)
	#print(text_changed_signal_list)
	
	
	var scroll_pos = text_edit.get_v_scroll_bar().value # get current pos and reset after, changing text causes a scroll action
	print("INVALIDATING::", text_edit.get_line(0))
	
	var current_line = text_edit.get_caret_line()
	#text_edit.start_action(TextEdit.ACTION_TYPING)
	for i in range(text_edit.get_line_count()):
		if i == current_line:
			continue
		var text = text_edit.get_line(i)
		DummyHelper.dummy_code_edit.set_line(i, text)
		text_edit.set_line(i, text)
		text_edit.undo()
	
	#text_edit.end_action()
	#text_edit.undo()
	
	text_edit.get_v_scroll_bar().set_value_no_signal(scroll_pos)
	text_edit.queue_redraw()
	
	await text_edit.get_tree().process_frame
	
	for data in text_changed_signal_list:
		var callable = data.get("callable")
		var flags = data.get("flags")
		text_edit.text_changed.connect(callable, flags)

func invalidate(line:=-1):
	#init_scan_done = false
	var text_edit = get_text_edit()
	if line == -1 or line > text_edit.get_line_count():
		line = text_edit.get_caret_line()
	var text = text_edit.get_line(line)
	DummyHelper.dummy_code_edit.set_line(line, text)
	text_edit.set_line(line, text)
	text_edit.undo()
