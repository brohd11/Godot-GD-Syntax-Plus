# HL
const PLUGIN_EXPORTED = false
const PRINT_DEBUG = false
const CAN_INVALIDATE = true

const TF = preload("uid://ft7o6vspsurv") #! resolve ALibRuntime.Utils.UProfile.TimeFunction

const HLInfo = SyntaxPlusSingleton.HLInfo

const SPClasses = preload("res://addons/syntax_plus/src/utils/classes.gd")

const UtilsRemote = SPClasses.UtilsRemote
const GDScriptParser = UtilsRemote.GDScriptParser
const UClassDetail = UtilsRemote.UClassDetail
const UObject = UtilsRemote.UObject

const DummyHelper = SPClasses.DummyHelper
const HighlightHelper = SPClasses.HighlightHelper
const TagHighlighter = SPClasses.TagHighlighter
const Utils = SPClasses.Utils

static var default_text_color:Color
static var editor_member_color:Color
static var string_color:Color
static var _empty_line_data:Dictionary = {}

static var const_color:Color
static var pascal_color:Color
static var member_color:Color
static var member_access_color:Color
static var inh_member_color:Color
static var base_type_member_color:Color
static var inner_class_member_color:Color
static var argument_color:Color

static var const_enable:bool
static var pascal_enable:bool
static var member_enable:bool
static var member_access_enable:bool
static var inh_member_enable:bool
static var inh_member_respect_case:bool
static var base_type_member_enable:bool
static var inner_class_member_enable:bool
static var inner_class_color_shift:bool
static var argument_enable:bool

static var tag_enable:bool
static var tag_color:Color
static var tag_color_enable:bool

static var editor_tags:Dictionary = {}

static var _const_regex:RegEx
static var _pascal_regex:RegEx

var gdscript_parser:GDScriptParser
var _members_hash:int = -1
var _script_extended #:GDScript
var _script_base_type:String
var script_resource:GDScript

var dummy_helper:DummyHelper

var highlight_helpers:Array[HighlightHelper] = []
var script_member_highlighters:Array[HighlightHelper] = []
var func_arg_highlighters:Dictionary[String, HighlightHelper] = {}
var inner_class_highlighters:Dictionary[String, HighlightHelper] = {}

var const_highlighter:HighlightHelper
var pascal_highlighter:HighlightHelper
var member_highlighter:HighlightHelper
var inherited_member_highlighter:HighlightHelper
var class_member_highlighter:HighlightHelper
var inner_class_member_highlighter:HighlightHelper

var tag_highlighter:TagHighlighter

var _text_edit:CodeEdit
var cache_dirty:= true

var tagged_data:Dictionary = {}

var current_line_last_state = ""
var last_line_count = 0

var init_scan_done:= false

var comment_tag_prefixes:= []


signal scanning_tags
signal queue_invalidate


func _init() -> void:
	dummy_helper = DummyHelper.new()
	create_highlight_helpers()

func set_text_edit(text_edit:TextEdit):
	_text_edit = text_edit

func get_text_edit():
	return _text_edit


func get_gdscript_parser() -> GDScriptParser:
	return gdscript_parser


func create_highlight_helpers():
	init_scan_done = false #^r NOT REDUNDANT
	
	# clear when reseting
	for highlight_helper in highlight_helpers:
		highlight_helper = null
	tag_highlighter = null
	tagged_data.clear()
	highlight_helpers.clear()
	script_member_highlighters.clear()
	func_arg_highlighters.clear()
	inner_class_highlighters.clear()
	
	_script_extended = null
	_members_hash = -1
	_script_base_type = ""
	# /clear
	
	if tag_enable:
		for tag in editor_tags:
			var data = editor_tags.get(tag)
			var highlighter = HighlightHelper.new(data.get("color"), tag, data)
			highlight_helpers.append(highlighter)
		
		tag_highlighter = TagHighlighter.new(editor_tags)
		tag_highlighter.tag_color_enabled = tag_color_enable
		tag_highlighter.highlight_color = tag_color
	
	
	if const_enable:
		const_highlighter = HighlightHelper.new(const_color)
		script_member_highlighters.append(const_highlighter)
		
	if pascal_enable:
		pascal_highlighter = HighlightHelper.new(pascal_color)
		script_member_highlighters.append(pascal_highlighter)
	
	if member_enable:
		member_highlighter = HighlightHelper.new(member_color)
		script_member_highlighters.append(member_highlighter)
		
	if inh_member_enable:
		inherited_member_highlighter = HighlightHelper.new(inh_member_color)
		script_member_highlighters.append(inherited_member_highlighter)
		
	if base_type_member_enable:
		class_member_highlighter = HighlightHelper.new(base_type_member_color)
		script_member_highlighters.append(class_member_highlighter)
	
	#if inner_class_member_enable:
		#inner_class_member_highlighter = HighlightHelper.new(inner_class_member_color)
		#script_member_highlighters.append(inner_class_member_highlighter)


func _on_caret_changed():
	var text_edit = get_text_edit()
	current_line_last_state = text_edit.get_line(text_edit.get_caret_line())


func get_line_syntax_highlighting(line_idx: int) -> Dictionary:
	var text_edit = get_text_edit() as CodeEdit
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
		
		# if line count less, update tagged name list and parse. This keeps the function names at proper idxes
		# update is needed to reset the last_line_count so that it doesn't run everytime
		# maybe another variable that is seperate from this one? Then parse can be ran on it's own
		if text_edit.get_line_count() < last_line_count:
			update_tagged_name_list()
			gdscript_parser.parse(true)
			
			# if not line count smaller, but it is the current line, check tags 
		elif line_idx == text_edit.get_caret_line():
			update_tagged_name_list()
	
	
	if current_line_text.strip_edges() == "":
		return _empty_line_data
	
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
				#if comment_index == 0:
				if current_line_text.strip_edges(true, false).begins_with("#"):
					return HLInfo.get_comment_tag_info(text_edit, current_line_text, line_idx, comment_tag_prefix, comment_tag_index)
				break
	
	#^ Not 100% sure duplicate is neces
	var hl_info:Dictionary = dummy_helper.base_gdscript_highlighter.get_line_syntax_highlighting(line_idx)
	if hl_info.has(0):
		var color = hl_info.get(0).get("color")
		if color == string_color and text_edit.is_in_string(line_idx, 0) == -1:
			DummyHelper.instance_highlighter() # this will fire once per frame max
			hl_info = dummy_helper.base_gdscript_highlighter.get_line_syntax_highlighting(line_idx)
	
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
	if tag_enable:
		for highlight_helper in highlight_helpers: 
			var check = highlight_helper.check_line(hl_info, current_line_text)
			hl_info = check[0]
			if not needs_sort:
				needs_sort = check[1]
	#^
	var valid_parser = is_instance_valid(gdscript_parser)
	var class_at_line = "" if not valid_parser else gdscript_parser.get_class_at_line(line_idx)
	
	#^ Member check
	for highlighter in script_member_highlighters:
		if not class_at_line.is_empty() and (highlighter == member_highlighter):
			continue # this could be a bit cleaner, perhaps having a set for every class. But for now it will work
		
		var member_check = highlighter.check_line(hl_info, current_line_text)
		hl_info = member_check[0]
		if not needs_sort:
			needs_sort = member_check[1]
	#^
	
	if inner_class_member_enable and not class_at_line.is_empty():
		var ic_hl_helper = inner_class_highlighters.get(class_at_line)
		if is_instance_valid(ic_hl_helper):
			var ic_check = ic_hl_helper.check_line(hl_info, current_line_text)
			hl_info = ic_check[0]
			if not needs_sort:
				needs_sort = ic_check[1]
		
	if argument_enable and valid_parser:
		var func_at_line = gdscript_parser.get_function_at_line(line_idx)
		var access_path = func_at_line
		if class_at_line != "":
			access_path = GDScriptParser.Utils.type_path_add_member(class_at_line, func_at_line)
		var hl_helper = func_arg_highlighters.get(access_path)
		if hl_helper:
			var arg_check = hl_helper.check_line(hl_info, current_line_text)
			hl_info = arg_check[0]
			if not needs_sort:
				needs_sort = arg_check[1]
	
	#^ Highlight tags
	if tag_enable:
		var tag_check = tag_highlighter.check_line(hl_info, current_line_text)
		hl_info = tag_check[0]
		if not needs_sort:
			needs_sort = tag_check[1]
	#^
	
	if comment_tag_prefix != "":
		hl_info = HLInfo.get_comment_tag_info(text_edit, current_line_text, line_idx, comment_tag_prefix, comment_tag_index, hl_info)
	
	if needs_sort:
		hl_info = HLInfo.sort_keys(hl_info)
	
	return hl_info

func update_tagged_name_list(force_build=false) -> void:
	
	_initialize_regexes()
	#var t = TF.new("UPDATE TAGGED NEW")
	var text_edit_node: CodeEdit = get_text_edit()
	if not text_edit_node.caret_changed.is_connected(_on_caret_changed):
		text_edit_node.caret_changed.connect(_on_caret_changed)
	
	var current_line_index = text_edit_node.get_caret_line()
	var current_line_text = text_edit_node.get_line(current_line_index)
	var current_line_count = text_edit_node.get_line_count()
	
	#^ new copy of data to compare to old if tagged removed or added to current line
	var new_tagged_data: Dictionary = {}
	for highlight_helper in highlight_helpers:
		var old_data = tagged_data.get(highlight_helper, {})
		new_tagged_data[highlight_helper] = old_data.duplicate()
	#^
	
	#^ if flags found, check for changes in current line
	var check = check_line_for_rebuild(current_line_text, current_line_last_state)
	if tag_enable and (check and not force_build):
		for highlight_helper in highlight_helpers:
			var declaration_regex = highlight_helper.declaration_regex
			var _match = declaration_regex.search(current_line_text)
			if _match:
				var tagged_name = _match.get_string(1)
				new_tagged_data[highlight_helper][tagged_name] = true
				break # break? only 1 per line?
			else:
				var last_match = declaration_regex.search(current_line_last_state)
				if last_match:
					var tagged_name = last_match.get_string(1)
					new_tagged_data[highlight_helper].erase(tagged_name)
					break
	
	#prints("UPDATE FULL::", force_build, tagged_data.hash() != new_tagged_data.hash(), script_resource)
	
	var inval = false
	#^ Full scan of doc for valid highlights
	if tag_enable and (force_build or tagged_data.hash() != new_tagged_data.hash()):
		#^ this can be pretty slow, 2+ ms on small files. On the other hand, gdscript parser
		#^ is about half the runtime. If that also stored comments, it could speed this up
		#^ could store comment to idx key, then loop through them
		#^c IF i want to retain this. at this point, I barely use the tags...
		#var update_tags = TF.new("UPDATE TAGS")
		
		for highlight_helper in highlight_helpers:
			new_tagged_data[highlight_helper].clear()
		
		for i in range(current_line_count):
			var line_names_found = [] # anything not in arary may be added to member regex
			var line_text = text_edit_node.get_line(i)
			for highlight_helper in highlight_helpers:
				var _match = highlight_helper.declaration_regex.search(line_text) #>debu
				if _match:
					var tagged_name = _match.get_string(1)
					new_tagged_data[highlight_helper][tagged_name] = true
					line_names_found.append(tagged_name)
		
		#update_tags.stop()
		
		tagged_data = new_tagged_data
		
		for highlight_helper in highlight_helpers:
			var highlight_data = new_tagged_data[highlight_helper]
			var chg = highlight_helper.set_highlight_words(highlight_data)
			if chg:
				inval = true
	
	 # if it hasn't been initialized, run it
	if not is_instance_valid(gdscript_parser):# or not init_scan_done: # not sure if init scan done flag needed, for when resetting highlighters
		var changed = update_class_members()
		if changed: # not sure if this is necessary.
			inval = true
	
	if inval: # fairly slow, would be nice to check if needed, any instances of word above
		#invalidate_all() # for this PC it's not really a big deal...
		invalidate(current_line_index)
	
	
	#^ Set state
	current_line_last_state = text_edit_node.get_line(current_line_index)
	last_line_count = text_edit_node.get_line_count()
	
	#t.stop()
	check_newline_buffer()


func update_class_members(allow_invalidate:=false) -> bool:
	if script_member_highlighters.is_empty():
		return false
	var t = TF.new("UPDATE CLASS MEMBERS")
	if not is_instance_valid(gdscript_parser):
		gdscript_parser = GDScriptParser.new()
		gdscript_parser.set_current_script(script_resource)
		gdscript_parser.set_code_edit(get_text_edit())
		gdscript_parser.set_parser_cache_size(0)
	
	
	gdscript_parser.parse()
	var main_class_obj = gdscript_parser.get_class_object() as GDScriptParser.ParserClass
	var parser_script_res = main_class_obj.script_resource
	
	
	var parser_hash = gdscript_parser.get_members_hash()
	var member_hash_ok = parser_hash == _members_hash
	_members_hash = parser_hash
	
	var base_type = parser_script_res.get_instance_base_type()
	var base_ok = base_type == _script_base_type
	_script_base_type = base_type
	
	if _script_extended is String:
		_script_extended = null
	var extended = parser_script_res.get_base_script()
	var extended_ok = extended == _script_extended
	_script_extended = extended
	
	#print("UPDATE PARSER::", gdscript_parser.get_current_script())
	#prints("CHECK::", member_hash_ok, extended_ok, base_ok, _script_base_type)
	if member_hash_ok and extended_ok and base_ok:
		#t.stop("UPDATE CLASS MEMBERS::EXIT")
		return false
	
	if inner_class_highlighters == null:
		inner_class_highlighters = {}
	
	var temp_func_arg_data:Dictionary[String, HighlightHelper] = {}
	
	_initialize_regexes()
	var members_changed:= false
	
	var new_const_words:= {}
	var new_pasc_words:= {}
	var new_member_words:= {}
	var new_inh_member_words:= {}
	var inner_class_member_words:= {}
	
	if is_instance_valid(class_member_highlighter):
		var new_base_type_members = UClassDetail.get_members_of_base_type(_script_base_type)
		var cl_chg := class_member_highlighter.set_highlight_words(new_base_type_members)
		members_changed = maxi(members_changed, cl_chg)
	
	for m in main_class_obj.get_inherited_members():
		if inh_member_respect_case:
			_check_word(m, new_const_words, new_pasc_words, new_inh_member_words)
		else:
			new_inh_member_words[m] = true
	
	if is_instance_valid(inherited_member_highlighter):
		var i_chg:= inherited_member_highlighter.set_highlight_words(new_inh_member_words)
		members_changed = maxi(members_changed, i_chg)
	
	for access_name in gdscript_parser.get_classes():
		var class_obj = gdscript_parser.get_class_object(access_name) as GDScriptParser.ParserClass
		
		for c:String in class_obj.constants:
			_check_word(c, new_const_words, new_pasc_words, new_member_words)
		
		for ic:String in class_obj.inner_classes:
			_check_word(ic, new_const_words, new_pasc_words, new_member_words)
		
		if access_name.is_empty():
			for m:String in class_obj.members:
				new_member_words[m] = true
			
		elif inner_class_member_enable:
			var ic_chg = get_or_create_inner_class_helper(class_obj)
			members_changed = maxi(members_changed, ic_chg)
			for m:String in class_obj.members:
				inner_class_member_words[m] = true
		
		if argument_enable:
			var ft = TF.new("FUNC ARG")
			var func_chg = get_or_create_func_arg_helpers(class_obj, temp_func_arg_data)
			members_changed = maxi(members_changed, func_chg)
			if PRINT_DEBUG:
				ft.stop()
			
		
	
	if is_instance_valid(const_highlighter):
		var c_chg := const_highlighter.set_highlight_words(new_const_words)
		members_changed = maxi(members_changed, c_chg)
	
	if is_instance_valid(pascal_highlighter):
		var p_chg := pascal_highlighter.set_highlight_words(new_pasc_words)
		members_changed = maxi(members_changed, p_chg)
	
	if is_instance_valid(member_highlighter):
		var m_chg := member_highlighter.set_highlight_words(new_member_words)
		members_changed = maxi(members_changed, m_chg)
	
	#if is_instance_valid(inner_class_member_highlighter):
		#var ic_chg := inner_class_member_highlighter.set_highlight_words(inner_class_member_words)
		#members_changed = maxi(members_changed, ic_chg)
	
	#print(member_highlighter.highlight_words.size())
	#print(member_highlighter.highlight_words.keys())
	#print(new_member_words.size())
	#print(new_member_words.keys())
	
	func_arg_highlighters = temp_func_arg_data
	
	#print("CLASS::","CAN INVAL::%s::" % allow_invalidate, "CHANGED::",members_changed)
	if allow_invalidate and members_changed:
		queue_invalidate.emit()
	
	if PRINT_DEBUG:
		t.stop()
	return members_changed

func get_or_create_inner_class_helper(class_obj:GDScriptParser.ParserClass):
	var highlight_helper = inner_class_highlighters.get(class_obj.access_path)
	if not is_instance_valid(highlight_helper):
		var depth = class_obj.access_path.count(".")
		var new_color = inner_class_member_color
		if depth > 0 and inner_class_color_shift:
			new_color.h = wrapf(new_color.h + (new_color.h * depth * 0.3), 0, 1)
			new_color.v = minf(new_color.v, 0.8)
		
		highlight_helper = HighlightHelper.new(new_color)
		inner_class_highlighters[class_obj.access_path] = highlight_helper
	
	var new_words = {}
	for m:String in class_obj.members:
		new_words[m] = true
	var chg = highlight_helper.set_highlight_words(new_words)
	return chg

func get_or_create_func_arg_helpers(class_obj:GDScriptParser.ParserClass, temp_data:Dictionary):
	var changed = false
	for f in class_obj.functions:
		var func_obj = class_obj.functions[f] as GDScriptParser.ParserFunc
		var args = func_obj.get_arguments_raw()
		if not args.is_empty():
			var access_path = GDScriptParser.Utils.type_path_add_member(class_obj.access_path, f)
			var highlight_helper = func_arg_highlighters.get(access_path) as HighlightHelper
			if not is_instance_valid(highlight_helper):
				highlight_helper = HighlightHelper.new(argument_color)
				changed = true
			
			var f_chg = highlight_helper.set_highlight_words(args)
			if not changed:
				changed = f_chg
			temp_data[access_path] = highlight_helper
	return changed

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
	if not const_enable:
		return false
	return _const_regex.search(text) != null

func _is_pascal(text:String):
	if not pascal_enable:
		return false
	return _pascal_regex.search(text) != null

func _initialize_regexes():
	if not is_instance_valid(_const_regex):
		_const_regex = RegEx.new()
		_const_regex.compile("\\b([A-Z_][A-Z_0-9]*)\\b") # allows to start with '_', wanted?
	if not is_instance_valid(_pascal_regex):
		_pascal_regex = RegEx.new()
		_pascal_regex.compile("\\b([A-Z]\\w*[a-z]\\w*)\\b")

static func check_line_for_rebuild(line_text:String, line_text_last_state:String):
	if line_text.strip_edges(false, true) == "": # unsure of this with args
		return true
	if line_text.find(Utils.FULL_TAG_CHAR) > -1:
		return true
	if line_text_last_state.find(Utils.FULL_TAG_CHAR) > -1:
		return true
	
	return false


func set_inactive():
	gdscript_parser = null
	for hl in script_member_highlighters:
		hl.set_highlight_words({})


func invalidate_all():
	_invalidate_all.call_deferred()



func _invalidate_all():
	if not CAN_INVALIDATE:
		return
	if PRINT_DEBUG:
		print("INVALIDATING::", script_resource)
	
	var text_edit = get_text_edit()
	var text_changed_signal_list = UObject.disconnect_signals_of_name(text_edit, "text_changed")
	DummyHelper.instance_highlighter()
	
	var top_line = text_edit.get_first_visible_line()
	var current_line = text_edit.get_caret_line()
	for i in range(text_edit.get_line_count()):
		if i == current_line:
			continue
		var text = text_edit.get_line(i)
		DummyHelper.dummy_code_edit.set_line(i, text)
		text_edit.set_line(i, text)
		text_edit.undo()
	
	text_edit.scroll_vertical = top_line # more reliable than scroll bar it seems
	await text_edit.get_tree().process_frame
	
	UObject.connect_signals_from_list(text_edit, text_changed_signal_list)



func invalidate(line:=-1):
	if not CAN_INVALIDATE:
		return
	
	var text_edit = get_text_edit()
	var text_changed_signal_list = UObject.disconnect_signals_of_name(text_edit, "text_changed")
	
	if line == -1 or line > text_edit.get_line_count():
		line = text_edit.get_caret_line()
	var text = text_edit.get_line(line)
	DummyHelper.dummy_code_edit.set_line(line, text)
	text_edit.set_line(line, text)
	text_edit.undo()
	
	UObject.connect_signals_from_list(text_edit, text_changed_signal_list)
