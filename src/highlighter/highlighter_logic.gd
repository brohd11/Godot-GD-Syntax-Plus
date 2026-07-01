# HL
const PLUGIN_EXPORTED = false
const PRINT_DEBUG = false
const CAN_INVALIDATE = true

const TF = preload("uid://ft7o6vspsurv") #! resolve ALibRuntime.Utils.UProfile.TimeFunction

const HLInfo = SyntaxPlusSingleton.HLInfo

const SPClasses = preload("res://addons/syntax_plus/src/utils/classes.gd")

const UtilsRemote = SPClasses.UtilsRemote
const GDScriptParser = UtilsRemote.GDScriptParser
const ParserClass = GDScriptParser.ParserClass
const ParserFunc = GDScriptParser.ParserFunc
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
var func_arg_highlighters:Dictionary[String, Dictionary] = {}
var inner_class_highlighters:Dictionary[String, Dictionary] = {}

var const_highlighter:HighlightHelper
var pascal_highlighter:HighlightHelper
var member_highlighter:HighlightHelper
var inherited_member_highlighter:HighlightHelper
var class_member_highlighter:HighlightHelper
var inner_class_member_highlighter:HighlightHelper

var tag_highlighter:TagHighlighter

var use_tree_sitter:bool = ClassDB.class_exists("GDScriptTreeSitter")

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
	return _get_gdscript_parser()


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


func _on_caret_changed():
	var text_edit = get_text_edit()
	current_line_last_state = text_edit.get_line(text_edit.get_caret_line())


func get_line_syntax_highlighting(line_idx: int) -> Dictionary:
	var text_edit = get_text_edit() as CodeEdit
	var current_line_text: String = text_edit.get_line(line_idx)
	if not init_scan_done:
		scanning_tags.emit()
		DummyHelper.set_code_edit()
		DummyHelper.dummy_code_edit.text = get_text_edit().text
		update_tagged_name_list(true)
		init_scan_done = true # set last to allow ts class members to run
	
	var parser = _get_gdscript_parser()
	var valid_parser = is_instance_valid(parser)
	if not valid_parser or not parser.cache_valid():
		update_class_members()
	
	if DummyHelper.dummy_code_edit.get_line(line_idx) != current_line_text:
		if line_idx >= DummyHelper.dummy_code_edit.get_line_count():
			check_newline_buffer()
		DummyHelper.dummy_code_edit.set_line(line_idx, current_line_text)
		
		# if line count less, update tagged name list and parse. This keeps the function names at proper idxes
		# update is needed to reset the last_line_count so that it doesn't run everytime
		# maybe another variable that is seperate from this one? Then parse can be ran on it's own
		if text_edit.get_line_count() < last_line_count:
			update_tagged_name_list()
			parser.parse(true)
			
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
	
	var class_at_line = ""
	for cls in inner_class_highlighters.keys():
		#if cls == "": # this should be irrelavent now that main class is removed.
			#continue
		var d = inner_class_highlighters[cls]
		if (d.line_index <= line_idx and d.end_line >= line_idx):
			class_at_line = cls
			break
	
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
		var ic_hl_helper = inner_class_highlighters[class_at_line].get(Keys.HELPER)
		if is_instance_valid(ic_hl_helper):
			var ic_check = ic_hl_helper.check_line(hl_info, current_line_text)
			hl_info = ic_check[0]
			if not needs_sort:
				needs_sort = ic_check[1]
	
	
	if argument_enable and valid_parser and func_arg_highlighters.has(class_at_line):
		var funcs = func_arg_highlighters.get(class_at_line)
		for d:Dictionary in funcs.values():
			if not (d.line_index <= line_idx and d.end_line >= line_idx):
				continue
			var hl_helper = d[Keys.HELPER]
			if hl_helper:
				var arg_check = hl_helper.check_line(hl_info, current_line_text)
				hl_info = arg_check[0]
				if not needs_sort:
					needs_sort = arg_check[1]
			break
	
	
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
	#if not is_instance_valid(gdscript_parser) or not init_scan_done: # not sure if init scan done flag needed, for when resetting highlighters
	if not init_scan_done: # init_scan_done not set after this func, all that is needed?
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



func _get_gdscript_parser():
	var editor_parser = ALibEditor.Singleton.EditorGDScriptParser.get_parser()
	if is_instance_valid(editor_parser) and editor_parser.get_current_script() == script_resource:
		return editor_parser
	if not is_instance_valid(gdscript_parser):
		gdscript_parser = GDScriptParser.new()
		gdscript_parser.set_current_script(script_resource)
		gdscript_parser.set_code_edit(get_text_edit())
		gdscript_parser.set_parser_cache_size(0)
	
	
	if gdscript_parser._class_access.is_empty():
		gdscript_parser.parse()
	return gdscript_parser


func update_class_members(allow_invalidate:=false) -> bool:
	if script_member_highlighters.is_empty():
		return false
		
	if use_tree_sitter:
		return update_class_members_ts()
	
	var t = TF.new("UPDATE CLASS MEMBERS")
	
	var parser = _get_gdscript_parser()
	parser.parse()
	
	var main_class_obj = parser.get_class_object() as ParserClass
	var class_names = parser.get_classes()
	var parser_script_res = main_class_obj.script_resource
	 
	var cache_ok = _parser_cache_valid(parser_script_res)
	var member_hash = parser.get_members_hash()
	var member_hash_ok = member_hash == _members_hash
	_members_hash = member_hash
	
	if cache_ok and member_hash_ok:
		for access_name in class_names:
			var class_obj = parser.get_class_object(access_name) as ParserClass
			if not access_name.is_empty():
				var start_idx = class_obj.line_indexes[0]
				var end_idx = class_obj.line_indexes[class_obj.line_indexes.size() - 1]
				update_inner_class_helper_lines(access_name, start_idx, end_idx)
			
			if argument_enable:
				for f in class_obj.functions.keys():
					var func_obj = class_obj.functions[f] as GDScriptParser.ParserFunc
					update_func_helper_lines(access_name, f, func_obj.declaration_line, func_obj.end_line)
		if PRINT_DEBUG:
			t.stop("UPDATE CLASS MEMBERS::EXIT")
		return false
	
	_initialize_regexes()
	
	var temp_func_arg_data:Dictionary[String, Dictionary] = {}
	
	var new_const_words:= {}
	var new_pasc_words:= {}
	var new_member_words:= {}
	var new_inh_member_words:= {}
	
	var members_changed:= _add_class_and_inherited_members(
		main_class_obj,
		new_const_words,
		new_pasc_words,
		new_inh_member_words
		)
	
	
	for access_name in class_names:
		var class_obj = parser.get_class_object(access_name) as ParserClass
		
		_add_members(access_name, class_obj.members.keys(), class_obj.constants.keys(), 
			new_const_words, new_pasc_words, new_member_words)
		
		if not access_name.is_empty():
			var start_idx = class_obj.line_indexes[0]
			var end_idx = class_obj.line_indexes[class_obj.line_indexes.size() - 1]
			var ic_chg = get_or_create_inner_class_helper(class_obj.members, access_name, start_idx, end_idx)
			members_changed = maxi(members_changed, ic_chg)
		
		if argument_enable:
			var ft = TF.new("FUNC ARG")
			temp_func_arg_data[access_name] = {}
			for f in class_obj.functions.keys():
				var func_obj = class_obj.functions[f] as GDScriptParser.ParserFunc
				var args = func_obj.get_arguments_raw().keys()
				var chg = get_or_create_func_arg_helpers_unified(access_name, f, func_obj.declaration_line, func_obj.end_line, args, temp_func_arg_data)
				members_changed = maxi(members_changed, chg)
			
			if PRINT_DEBUG:
				ft.stop()
	
	var mem_chg = _set_hl_words(new_const_words, new_pasc_words, new_member_words)
	members_changed = maxi(members_changed, mem_chg)
	
	func_arg_highlighters = temp_func_arg_data
	_clean_up_inner_class_highlighters(class_names)
	
	#print("CLASS::","CAN INVAL::%s::" % allow_invalidate, "CHANGED::",members_changed)
	if allow_invalidate and members_changed:
		queue_invalidate.emit()
	
	if PRINT_DEBUG:
		t.stop()
	return members_changed


func update_class_members_ts() -> bool:
	var t = TF.new("UPDATE CLASS MEMBERS TS")
	var ts = ALibRuntime.Utils.UProfile.TimeFunction.new("Sparse", TF.TimeScale.USEC)
	
	var parser = _get_gdscript_parser()
	var main_class_obj = parser.get_class_object() as ParserClass
	var parser_script_res = main_class_obj.script_resource
	 
	var ts_man = parser.get_code_edit_parser().tree_sitter_manager
	var parsed = ts_man.parse_text()
	if not parsed and not member_highlighter.highlight_words.is_empty():
		if PRINT_DEBUG:
			ts.stop("Eearly Sparse exit")
		return false
	var sparse:Dictionary = ts_man.parser.sparse_parse()
	
	
	if PRINT_DEBUG:
		ts.stop()
	var member_data:Dictionary = sparse["members"]
	var class_names = member_data.keys()
	var line_data:Dictionary = sparse["lines"]
	
	var cache_ok:bool = _parser_cache_valid(parser_script_res)
	var member_hash:int = member_data.hash()
	var member_hash_ok:bool = member_hash == _members_hash
	_members_hash = member_hash
	if cache_ok and member_hash_ok and init_scan_done:
		# update lines since we are here
		for access_path in class_names:
			var class_line_data = line_data[access_path]
			if not access_path.is_empty():
				var cls_start_i = class_line_data[Keys.LINE_INDEX]
				var cls_end_i = class_line_data.get(Keys.END_LINE, cls_start_i)
				update_inner_class_helper_lines(access_path, cls_start_i, cls_end_i)
			
			if argument_enable:
				var functions = class_line_data["functions"]
				for f in functions.keys():
					var func_line_data = functions.get(f)
					var start_i = func_line_data.get(Keys.LINE_INDEX)
					var end_i = func_line_data.get(Keys.END_LINE, start_i)# + 1\
					update_func_helper_lines(access_path, f, start_i, end_i)
		
		if PRINT_DEBUG:
			t.stop("UPDATE CLASS MEMBERS TS::EXIT")
		return false
	elif not cache_ok: # makes sure inner classes are all correct.
		parser.parse()
	
	_initialize_regexes()
	var temp_func_arg_data:Dictionary[String, Dictionary] = {}
	
	var new_const_words:= {}
	var new_pasc_words:= {}
	var new_member_words:= {}
	var new_inh_member_words:= {}
	
	var members_changed:= _add_class_and_inherited_members(
		main_class_obj,
		new_const_words,
		new_pasc_words,
		new_inh_member_words
		)
	
	#print(sparse)
	for access_name in class_names:
		var class_data = member_data[access_name]
		var class_line_data = line_data[access_name]
		
		var members = class_data["members"]
		var constants = class_data["constants"]
		var functions = class_data["functions"]
		members.append_array(functions.keys()) # functions are separate from members, join them in
		
		_add_members(access_name, members, constants, new_const_words, new_pasc_words, new_member_words)
		
		if not access_name.is_empty():
			var cls_start_i = class_line_data[Keys.LINE_INDEX]
			var cls_end_i = class_line_data.get(Keys.END_LINE, cls_start_i)
			var ic_chg = get_or_create_inner_class_helper(members, access_name, cls_start_i, cls_end_i)
			members_changed = maxi(members_changed, ic_chg)
		
		if argument_enable:
			var ft = TF.new("FUNC ARG")
			temp_func_arg_data[access_name] = {}
			for f in functions.keys():
				var data = functions[f]
				var func_line_data = class_line_data["functions"].get(f)
				var start_i = func_line_data.get(Keys.LINE_INDEX)
				var end_i = func_line_data.get(Keys.END_LINE, start_i)# + 1
				var chg = get_or_create_func_arg_helpers_unified(access_name, f, start_i, end_i, data.get(&"args"), temp_func_arg_data)
				members_changed = maxi(members_changed, chg)
			
			if PRINT_DEBUG:
				ft.stop()
	
	
	var mem_chg = _set_hl_words(new_const_words, new_pasc_words, new_member_words)
	members_changed = maxi(members_changed, mem_chg)
	
	func_arg_highlighters = temp_func_arg_data
	_clean_up_inner_class_highlighters(class_names)
	
	#if allow_invalidate and members_changed: queue_invalidate.emit() #^r i think tree sitter can just not do this
	if PRINT_DEBUG:
		t.stop()
	return members_changed

func _add_class_and_inherited_members(main_class_obj:ParserClass,
		new_c_w:Dictionary, new_p_w:Dictionary, new_inh_w:Dictionary) -> bool:
	var members_changed:=false
	if is_instance_valid(class_member_highlighter):
		var new_base_type_members = UClassDetail.get_members_of_base_type(_script_base_type)
		var cl_chg := class_member_highlighter.set_highlight_words(new_base_type_members)
		members_changed = maxi(members_changed, cl_chg)
	
	for m in main_class_obj.get_inherited_members():
		if inh_member_respect_case:
			_check_word(m, new_c_w, new_p_w, new_inh_w)
		else:
			new_inh_w[m] = true
	
	if is_instance_valid(inherited_member_highlighter):
		var i_chg:= inherited_member_highlighter.set_highlight_words(new_inh_w)
		members_changed = maxi(members_changed, i_chg)
	return members_changed

func _add_members(access:String, mem:Array, con:Array, new_con_w, new_pas_w, new_mem_w):
	if access.is_empty():
		for m:String in mem:
			new_mem_w[m] = true
	else:
		_check_word(access.get_file(), new_con_w, new_pas_w, new_mem_w)
	
	for c:String in con:
		_check_word(c, new_con_w, new_pas_w, new_mem_w)

func _clean_up_inner_class_highlighters(current_classes:Array):
	inner_class_highlighters.erase("")
	for path in inner_class_highlighters.keys():
		if not path in current_classes:
			inner_class_highlighters.erase(path)

func _set_hl_words(new_c_w:Dictionary, new_p_w:Dictionary, new_mem_w:Dictionary):
	var members_changed:= false
	if is_instance_valid(const_highlighter):
		var c_chg := const_highlighter.set_highlight_words(new_c_w)
		members_changed = maxi(members_changed, c_chg)
	
	if is_instance_valid(pascal_highlighter):
		var p_chg := pascal_highlighter.set_highlight_words(new_p_w)
		members_changed = maxi(members_changed, p_chg)
	
	if is_instance_valid(member_highlighter):
		var m_chg := member_highlighter.set_highlight_words(new_mem_w)
		members_changed = maxi(members_changed, m_chg)
	return members_changed

func update_inner_class_helper_lines(class_path:String, start_line:int, end_line:int):
	var highlight_helper_data = inner_class_highlighters.get_or_add(class_path, {})
	highlight_helper_data[Keys.LINE_INDEX] = start_line
	highlight_helper_data[Keys.END_LINE] = end_line

func update_func_helper_lines(access_name:String, func_name:String, start_idx:int, end_idx:int):
	var data = func_arg_highlighters.get(access_name, {}).get(func_name)
	if data == null:
		return
	data[Keys.LINE_INDEX] = start_idx
	data[Keys.END_LINE] = end_idx

func get_or_create_inner_class_helper(members:Variant, class_path:String, start_line:int, end_line:int):
	var highlight_helper_data = inner_class_highlighters.get_or_add(class_path, {})
	highlight_helper_data[Keys.LINE_INDEX] = start_line
	highlight_helper_data[Keys.END_LINE] = end_line
	
	if not inner_class_member_enable:
		return false
	
	var highlight_helper = highlight_helper_data.get(Keys.HELPER)
	if not is_instance_valid(highlight_helper):
		var depth = class_path.count(".")
		var new_color = inner_class_member_color
		if depth > 0 and inner_class_color_shift:
			new_color.h = wrapf(new_color.h + (new_color.h * depth * 0.3), 0, 1)
			new_color.v = minf(new_color.v, 0.8)
		
		highlight_helper = HighlightHelper.new(new_color)
		highlight_helper_data[Keys.HELPER] = highlight_helper
	
	var new_words = {}
	for m:String in members:
		new_words[m] = true
	var chg = highlight_helper.set_highlight_words(new_words)
	return chg


func get_or_create_func_arg_helpers_unified(access_name:String, func_name:String, start_idx:int, end_idx:int, args:Array, temp_data:Dictionary):
	var changed = false
	if not args.is_empty(): 
		var access_path = GDScriptParser.Utils.type_path_add_member(access_name, func_name)
		var highlight_helper = func_arg_highlighters.get(access_path) as HighlightHelper
		if not is_instance_valid(highlight_helper):
			highlight_helper = HighlightHelper.new(argument_color)
			changed = true
		
		var f_chg = highlight_helper.set_highlight_words(args)
		if not changed:
			changed = f_chg
		temp_data[access_name][func_name] = {
				Keys.HELPER:highlight_helper,
				Keys.LINE_INDEX: start_idx,
				Keys.END_LINE: end_idx
			}
	return changed


# unused
func _get_line_range(data:Dictionary):
	var start = data.get(Keys.LINE_INDEX)
	var end = data.get(Keys.END_LINE, start) + 1
	return range(start, end)

func _parser_cache_valid(script):
	var base_type = script.get_instance_base_type()
	var base_ok = base_type == _script_base_type
	_script_base_type = base_type
	
	if _script_extended is String:
		_script_extended = null
	var extended = script.get_base_script()
	var extended_ok = extended == _script_extended
	_script_extended = extended
	
	return extended_ok and base_ok


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
	if use_tree_sitter:
		return
	_invalidate_all.call_deferred()

func _invalidate_all():
	if not CAN_INVALIDATE:
		return
	if PRINT_DEBUG:
		print("INVALIDATING::", script_resource)
	
	var text_edit = get_text_edit()
	if text_edit.has_redo():
		return
	var text_changed_signal_list = UObject.disconnect_signals_of_name(text_edit, "text_changed")
	DummyHelper.instance_highlighter()
	#return
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
	if text_edit.has_redo():
		return
	var text_changed_signal_list = UObject.disconnect_signals_of_name(text_edit, "text_changed")
	
	if line == -1 or line > text_edit.get_line_count():
		line = text_edit.get_caret_line()
	var text = text_edit.get_line(line)
	DummyHelper.dummy_code_edit.set_line(line, text)
	text_edit.set_line(line, text)
	text_edit.undo()
	
	UObject.connect_signals_from_list(text_edit, text_changed_signal_list)

class Keys extends GDScriptParser.Keys:
	const HELPER = &"helper"
