@tool
extends RefCounted

const Utils = preload("uid://bvmvgtxctmgl") #import utils.gd
const GDHelper = preload("uid://es6q2q0qg7pj")  #import gdscript_helper.gd

var tagged_names: Array = [] # Stores the names of consts marked for special highlighting
var _tagged_name_regex: RegEx # Dynamically built regex for these names
var declaration_regex: RegEx # To find "const NAME = xxx #import"

var highlight_color:Color
var highlight_tag:String = ""
var overwrite_color:bool = false

func _init(tag, tag_data) -> void:
	highlight_tag = tag
	var keywords:String = tag_data.get("keyword", "any")
	
	var color = tag_data.get("color", "#35cc9b")
	if not color.begins_with("#"):
		color = "#" + color
	var color_obj = Color(color)
	highlight_color = color_obj
	
	var overwrite = tag_data.get("overwrite", false)
	if overwrite is String:
		overwrite = overwrite.to_lower()
		if overwrite == "true":
			overwrite = true
		else:
			overwrite = false
	overwrite_color = overwrite
	
	var pattern = Utils.get_regex_pattern(keywords, tag)
	declaration_regex = RegEx.new()
	var err = declaration_regex.compile(pattern)
	if err != OK:
		printerr("CustomHighlighter: Regex compilation error for declaration_regex")
		declaration_regex.compile("(?!)")
	
	rebuild_tagged_name_regex() # Initialize with an empty regex


func check_line(hl_info, current_line_text):
	var needs_sort = false
	
	if not tagged_names.is_empty() and is_instance_valid(_tagged_name_regex):
		var const_matches = _tagged_name_regex.search_all(current_line_text)
		for const_match in const_matches:
			var start_col = const_match.get_start(1)
			var end_col = const_match.get_end(1)
			var can_highlight = true
			if not start_col in hl_info and not overwrite_color:
				var index = start_col - 1
				while index > 0:
					if hl_info.has(index):
						var existing_color:Color = hl_info[index].get("color", Color.BLACK)
						if existing_color != GDHelper.default_text_color:
							
							can_highlight = false
							break
					index -= 1
				if not can_highlight:
					continue
				#else:
					#needs_sort = true
					#hl_info[start_col] = {"color": highlight_color}
			
			for i in range(start_col, end_col):
				if hl_info.has(i) and not overwrite_color:
					var existing_color:Color = hl_info[i].get("color", Color.BLACK)
					if existing_color != GDHelper.default_text_color:
						can_highlight = false
						break
			if can_highlight:
				needs_sort = true
				for i in range(start_col, end_col):
					hl_info[i] = {"color": highlight_color}
	
	return [hl_info, needs_sort]

func rebuild_tagged_name_regex():
	if tagged_names.is_empty():
		if is_instance_valid(_tagged_name_regex): # Check if already created
			_tagged_name_regex.compile("(?!)") # Non-matching regex
		else:
			_tagged_name_regex = RegEx.new()
			_tagged_name_regex.compile("(?!)")
		return
	
	var pattern_parts = []
	for name in tagged_names:
		pattern_parts.append(Utils.escape_regex_meta_characters(str(name))) # Escape the name
	
	if not is_instance_valid(_tagged_name_regex):
		_tagged_name_regex = RegEx.new()
	
	var err = _tagged_name_regex.compile("\\b(" + "|".join(pattern_parts) + ")\\b")
	if err != OK:
		printerr("CustomHighlighter: Regex compilation error for imported consts: ", err)
		_tagged_name_regex.compile("(?!)")
