extends RefCounted

const UNCOLORED_BG = Color(0,0,0,0)

#^ settings
var default_color:Color = Color.STEEL_BLUE
var default_bg_darken:float = 0.8
var color_pairs = {}

var comment_color:Color

#^ vars
var group_data:= {}
var misc_data:= {}
var fg_color_indexes:= {}
var bg_color_indexes:= {}

func _init() -> void:
	SyntaxPlus.register_highlight_callable("#^", "", _highlight_comment, SyntaxPlus.CallableLocation.ANY)
	
	ScriptEditorRef.subscribe(ScriptEditorRef.Event.VALIDATE_SCRIPT, _on_validate_script)
	ScriptEditorRef.subscribe(ScriptEditorRef.Event.TEXT_CHANGED, _on_text_changed)
	_init_settings()

func _init_settings():
	var ed_settings = EditorInterface.get_editor_settings()
	
	if not ed_settings.has_setting(Settings.DEFAULT_COLOR):
		ed_settings.set_setting(Settings.DEFAULT_COLOR, Settings._DEFAULT_COLOR)
	if not ed_settings.has_setting(Settings.DEFAULT_BG):
		ed_settings.set_setting(Settings.DEFAULT_BG, Settings._DEFAULT_BG)
	if not ed_settings.has_setting(Settings.COLOR_PAIRS):
		ed_settings.set_setting(Settings.COLOR_PAIRS, Settings.DEFAULT_COLOR_PAIRS)
	
	_set_settings()
	ed_settings.settings_changed.connect(_on_editor_settings_changed)

func _on_editor_settings_changed():
	_set_settings()

func _set_settings():
	var ed_settings = EditorInterface.get_editor_settings()
	default_color = ed_settings.get_setting(Settings.DEFAULT_COLOR)
	default_bg_darken = ed_settings.get_setting(Settings.DEFAULT_BG)
	color_pairs = ed_settings.get_setting(Settings.COLOR_PAIRS)
	
	comment_color = SyntaxPlus.get_instance().comment_color


func syntax_plus_notification(what:int):
	if what == 0:
		return
		#_read_group_data()

func _on_text_changed():
	#group_data.clear()
	pass

func _clear_all():
	group_data.clear()
	misc_data.clear()
	fg_color_indexes.clear()
	bg_color_indexes.clear()

func _on_validate_script():
	_read_group_data()
	set_backgrounds()

func set_backgrounds():
	_set_background_colors()

func _highlight_comment(script_editor:CodeEdit, current_line_text:String, line:int, comment_tag_idx:int):
	#if group_data.is_empty(): #^r would be nice to only run once
		#_read_group_data()
	
	var substr = current_line_text.substr(comment_tag_idx + 2)
	var first_word = substr.get_slice(" ", 0)
	
	var has_open_brack = false
	var has_close_brack = false
	var open_brack_i = first_word.find("{")
	var close_brack_i = first_word.find("}")
	if open_brack_i > -1:
		has_open_brack = true
		first_word = first_word.substr(0, open_brack_i)
		open_brack_i = open_brack_i - 1 # set this to - 1 to hl the bracket
	if close_brack_i > -1:
		has_close_brack = true
		first_word = first_word.substr(0, close_brack_i)
		close_brack_i = close_brack_i - 1 # set this to - 1 to hl the bracket
	
	if has_open_brack or has_close_brack:
		_read_group_data()
	
	var hl_color = null
	var fg_color = null
	var bg_color = null
	
	if fg_color_indexes.has(line):
		if first_word != "":
			hl_color = _get_color(first_word)
			fg_color = fg_color_indexes.get(line)
		elif first_word == "" or has_open_brack or has_close_brack:
			fg_color = fg_color_indexes.get(line)
			hl_color = fg_color
	else:
		hl_color = _get_color(first_word)
		fg_color = hl_color
	
	if bg_color_indexes.has(line):
		bg_color = bg_color_indexes.get(line)
	if bg_color == null:
		bg_color = comment_color
	
	var hl_info = {}
	#^ start of line hl overide
	hl_info[-2] = _hl_info_color_dict(hl_color)
	hl_info[-1] = _hl_info_color_dict(hl_color)
	
	#^ Open Bracket
	if has_open_brack:
		hl_info[open_brack_i] = _hl_info_color_dict(bg_color)
		var open_sq_i = substr.find("[")
		var close_sq_i = substr.find("]")
		if open_sq_i > -1 and close_sq_i > -1:
			hl_info[open_sq_i - 1] = _hl_info_color_dict(fg_color)
			var split_i = substr.find("/")
			if split_i > -1:
				hl_info[split_i] = _hl_info_color_dict(bg_color)
				hl_info[close_sq_i - 1] = _hl_info_color_dict(fg_color)
			if has_close_brack:
				hl_info[close_sq_i] = _hl_info_color_dict(bg_color)
				hl_info[close_brack_i + 1] = _hl_info_color_dict(hl_color)
			else:
				hl_info[close_sq_i + 1] = _hl_info_color_dict(hl_color)
		else:
			if has_close_brack:
				hl_info[close_brack_i + 1] = _hl_info_color_dict(hl_color)
			else:
				hl_info[open_brack_i + 1] = _hl_info_color_dict(hl_color)
	
	#^ Close Bracket
	if has_close_brack and not has_open_brack:
		var multi_bracket_end
		if misc_data.has("multi_bracket_ends") and misc_data["multi_bracket_ends"].has(line):
			multi_bracket_end = misc_data["multi_bracket_ends"][line]
			pass
		if multi_bracket_end == null:
			hl_info[close_brack_i] = _hl_info_color_dict(bg_color)
		else:
			var i = 0
			while i < substr.length() and multi_bracket_end.size() > 0:
				var char = substr[i]
				if char == "}":
					var color = multi_bracket_end.pop_front()
					if color == null:
						color = comment_color
					hl_info[close_brack_i + i] = _hl_info_color_dict(color)
				
				if multi_bracket_end.is_empty():
					close_brack_i += i # set this to i so that we can set it proper below
					break
				
				i += 1
		#^ apply to both cases
		hl_info[close_brack_i + 1] = _hl_info_color_dict(hl_color)
	
	return hl_info


func _read_group_data():
	_clear_all()
	
	var script_editor = ScriptEditorRef.get_current_code_edit()
	if script_editor == null:
		return
	#var t = ALibRuntime.Utils.UProfile.TimeFunction.new("READ GROUP")
	
	var group_id = 0
	var bracket_stack = []
	var bracket_stack_size:int = 0
	
	var line_count = script_editor.get_line_count()
	for i in range(line_count):
		var line = script_editor.get_line(i)
		var stripped = line.strip_edges()
		var tag_idx = stripped.find("#^")
		var has_tag = tag_idx > -1
		if not has_tag and bracket_stack_size == 0:
			continue
		var sub_str = stripped.substr(tag_idx + 2)
		var open_brack_i = sub_str.find("{")
		if open_brack_i > -1:
			sub_str = sub_str.substr(open_brack_i)
		
		if open_brack_i > -1 and has_tag:
			var sq_brack_i = stripped.find("]")
			var color_data = _get_bracket_color_data(stripped)
			if bracket_stack.is_empty():
				group_id += 1
				group_data[group_id] = {}
			
			bracket_stack.push_back("{")
			bracket_stack_size = bracket_stack.size()
			group_data[group_id][bracket_stack_size] = {
				"fg_color": color_data.fg_color,
				"bg_color": color_data.bg_color,
				"bg_darken": color_data.bg_darken,
				"indexes": [i]
			}
			if sub_str.find("}") > -1:
				var b = bracket_stack.pop_back()
				bracket_stack_size = bracket_stack.size()
			
		elif sub_str.find("}") > -1 and has_tag:
			var bracket_count = 1
			var close_brack_idx = sub_str.find("}")
			var char = sub_str[close_brack_idx]
			while char == "}" and close_brack_idx < sub_str.length() - 1:
				close_brack_idx += 1
				char = sub_str[close_brack_idx]
				if char == "}":
					bracket_count += 1
			
			if bracket_stack_size < bracket_count:
				_clear_all()
				return # compile error, return
			
			group_data[group_id][bracket_stack_size]["indexes"].append(i)
			
			if bracket_count > 1:
				misc_data.get_or_add("multi_bracket_ends", {})
				var bracket_colors = []
				for bc in range(bracket_count):
					var target_bracket_data_i = bracket_stack_size - bc
					var data = group_data[group_id][target_bracket_data_i]
					bracket_colors.push_back(data.get("bg_color"))
				
				misc_data["multi_bracket_ends"][i] = bracket_colors
			
			for c in range(bracket_count):
				var b = bracket_stack.pop_back()
			bracket_stack_size = bracket_stack.size()
			
		elif not bracket_stack.is_empty():
			group_data[group_id][bracket_stack_size]["indexes"].append(i)
	
	if not bracket_stack.is_empty():
		_clear_all()
		return # compile error, return
	
	for id in group_data.keys():
		var group = group_data[id]
		for bracket_group in group.keys():
			var bracket_data = group[bracket_group]
			var idxes = bracket_data.get("indexes")
			var fg_color = bracket_data.get("fg_color")
			var bg_color = bracket_data.get("bg_color")
			var bg_darken = bracket_data.get("bg_darken")
			for i in idxes:
				if bg_color != null:
					bg_color_indexes[i] = bg_color
				if fg_color != null:
					fg_color_indexes[i] = fg_color
	#t.stop()


func _set_background_colors():
	var script_editor = ScriptEditorRef.get_current_code_edit()
	for id in group_data.keys():
		var group = group_data[id]
		for bracket_group in group.keys():
			var bracket_data = group[bracket_group]
			var idxes = bracket_data.get("indexes")
			var bg_color = bracket_data.get("bg_color")
			if bg_color == null:
				continue
			var bg_darken = bracket_data.get("bg_darken")
			for i in idxes:
				var existing_color = script_editor.get_line_background_color(i)
				if existing_color != UNCOLORED_BG:
					continue
				script_editor.set_line_background_color(i, bg_color.darkened(bg_darken))


func _get_bracket_color_data(stripped_line:String):
	var sq_brack_i = stripped_line.find("]")
	var fg_color = null #^ should these be swapped?
	var bg_color = default_color #^ should these be swapped?
	var bg_darken_amout = default_bg_darken
	if sq_brack_i > -1 and stripped_line.find("{") > -1:
		var color_slice = stripped_line.get_slice("]", 0)
		color_slice = color_slice.get_slice("[", 1)
		var bg_color_str = ""
		if color_slice.find("/") > -1:
			fg_color = color_slice.get_slice("/", 0)
			bg_color_str = color_slice.get_slice("/", 1)
		else:
			bg_color_str = color_slice
		if fg_color != null:
			fg_color = _get_color(fg_color)
		if bg_color_str == "-":
			bg_color = null
		else:
			bg_color = _get_color(bg_color_str)
		bg_darken_amout = _get_bg_darken(bg_color_str)
	else:
		if stripped_line.find("}") > -1:
			var inner_color = stripped_line.get_slice("{", 1)
			inner_color = inner_color.get_slice("}", 0).strip_edges()
			if inner_color == "-":
				bg_color = null
			else:
				bg_color = _get_color(inner_color)
			bg_darken_amout = _get_bg_darken(inner_color)
	
	
	return {"fg_color":fg_color, "bg_color":bg_color, "bg_darken": bg_darken_amout}


func _get_color(color_string:String="", bg:=false, darken_amt:=0.8):
	var color:Color = default_color
	if color_string == "":
		pass
	elif color_string == "-":
		return comment_color
	elif color_pairs.has(color_string):
		var color_data = color_pairs.get(color_string)
		color = color_data.get("color")
		darken_amt = color_data.get("bg", default_bg_darken)
	var color_data = {"color":color}
	if bg:
		color = color.darkened(darken_amt)
	
	return color

func _get_bg_darken(color_string:String=""):
	if color_pairs.has(color_string):
		var color_data = color_pairs.get(color_string)
		return color_data.get("bg", default_bg_darken)
	return default_bg_darken

func _hl_info_color_dict(color):
	return {"color": color}


static func _reset_settings():
	var ed_settings = EditorInterface.get_editor_settings()
	ed_settings.set_setting(Settings.DEFAULT_COLOR, null)
	ed_settings.set_setting(Settings.DEFAULT_BG, null)
	ed_settings.set_setting(Settings.COLOR_PAIRS, null)
	
	if not ed_settings.has_setting(Settings.DEFAULT_COLOR):
		ed_settings.set_setting(Settings.DEFAULT_COLOR, Settings._DEFAULT_COLOR)
	if not ed_settings.has_setting(Settings.DEFAULT_BG):
		ed_settings.set_setting(Settings.DEFAULT_BG, Settings._DEFAULT_BG)
	if not ed_settings.has_setting(Settings.COLOR_PAIRS):
		ed_settings.set_setting(Settings.COLOR_PAIRS, Settings.DEFAULT_COLOR_PAIRS)



class Settings:
	const DEFAULT_COLOR = &"plugin/syntax_plus/extensions/comment_highlight/default_color"
	const DEFAULT_BG = &"plugin/syntax_plus/extensions/comment_highlight/default_bg"
	const COLOR_PAIRS = &"plugin/syntax_plus/extensions/comment_highlight/color_pairs"
	
	const _DEFAULT_COLOR = Color.STEEL_BLUE
	const _DEFAULT_BG = 0.8
	const DEFAULT_COLOR_PAIRS = {
		"w":{
			"color":Color.WHITE_SMOKE,
			"bg":0.8
			},
		"r":{
			"color":Color.FIREBRICK,
			"bg":0.8
			},
		"g":{
			"color":Color.WEB_GREEN,
			"bg":0.8
			},
		"b":{
			"color":Color.DODGER_BLUE,
			"bg":0.8
			},
		"c":{
			"color":Color.DARK_CYAN,
			"bg":0.8
			},
	}
