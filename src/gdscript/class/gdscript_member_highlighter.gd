@tool
extends RefCounted

const Utils = preload("res://addons/syntax_plus/src/gdscript/class/syntax_plus_utils.gd") #>import utils.gd
const GDHelper = preload("res://addons/syntax_plus/src/gdscript/editor/gdscript_helper.gd")  #>import gdscript_helper.gd

var script_class_name:String = "No Class"
var class_member_names:Array = []
var class_member_regex: RegEx

var script_member_names: Dictionary = {}
var script_member_regex: RegEx
var declaration_regex: RegEx

var member_highlight_mode:Utils.MemberMode = Utils.MemberMode.ALL
var highlight_color:Color
var highlight_tag:String = ""
var overwr:bool = false # I think can get rid of

func _init(tag, cfg_data) -> void:
	highlight_tag = tag
	var keywords:String = cfg_data.get("keyword", "any")
	
	member_highlight_mode = cfg_data.get(Utils.Config.member_highlight_mode, Utils.MemberMode.ALL)
	var color = cfg_data.get("color", Utils.DEFAULT_COLOR_STRING)
	highlight_color = Color.html(color)
	var pattern = Utils.get_regex_pattern(keywords, tag)
	declaration_regex = RegEx.new()
	var err = declaration_regex.compile(pattern)
	if err != OK:
		printerr("CustomHighlighter: Regex compilation error for declaration_regex")
		declaration_regex.compile("(?!)")
	
	rebuild_script_member_regex() # Initialize with an empty regex
	rebuild_class_member_regex()

func check_class_valid():
	if script_class_name != Utils.get_current_script_class():
		script_class_name = Utils.get_current_script_class()
		var class_member_check = Utils.get_all_class_members()
		if class_member_check.hash() != class_member_names.hash():
			class_member_names = class_member_check
			rebuild_class_member_regex()


func check_line(hl_info, current_line_text):
	var check_class:= false
	var check_script:= false
	if member_highlight_mode == Utils.MemberMode.NONE:
		return [hl_info, false]
	elif member_highlight_mode == Utils.MemberMode.ALL:
		check_class = true
		check_script = true
	elif member_highlight_mode == Utils.MemberMode.INHERITED:
		check_class = true
	elif member_highlight_mode == Utils.MemberMode.SCRIPT:
		check_script = true
	
	var t = current_line_text
	var needs_sort = false
	if check_script:
		var check = check_line_hl(hl_info, t, script_member_names, script_member_regex, highlight_color, overwr)
		hl_info = check[0]
		needs_sort = check[1]
	if check_class:
		var check = check_line_hl(hl_info, t, class_member_names, class_member_regex, highlight_color, overwr)
		hl_info = check[0]
		needs_sort = check[1]
	 
	return [hl_info, needs_sort]


func rebuild_script_member_regex():
	script_member_regex = Utils.build_name_regex(script_member_names.keys())

func rebuild_class_member_regex():
	class_member_regex = Utils.build_name_regex(class_member_names)

static func check_line_hl(hl_info, current_line_text, name_array, regex, hl_color, overwrite):
	var needs_sort = false
	if not name_array.is_empty() and is_instance_valid(regex):
		var _matches = regex.search_all(current_line_text)
		for _match in _matches:
			var start_idx = _match.get_start(1)
			if not overwrite:
				var index_data = hl_info.get(start_idx)
				if index_data == null:
					continue
				var existing_color = hl_info.get(start_idx, {}).get("color")
				if existing_color != GDHelper.default_text_color:
					continue
			else:
				if not start_idx in hl_info:
					var end_idx = _match.get_end(1)
					if end_idx != current_line_text.length():
						var idx = start_idx + 1
						while idx >= 0:
							var index_data = hl_info.get(idx)
							if index_data:
								var existing_color = index_data.get("color")
								hl_info[end_idx] = {"color": existing_color}
								break
							
							idx -= 1
			
			needs_sort = true
			hl_info[start_idx] = {"color": hl_color}
	
	return [hl_info, needs_sort]
