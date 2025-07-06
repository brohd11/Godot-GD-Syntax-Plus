@tool
extends RefCounted

const Utils = preload("uid://bvmvgtxctmgl") #>import utils.gd
const GDHelper = preload("uid://es6q2q0qg7pj")  #>import gdscript_helper.gd

var tagged_names: Array = [] # Stores the names of consts marked for special highlighting
var _tagged_name_regex: RegEx # Dynamically built regex for these names
var declaration_regex: RegEx # To find "const NAME = xxx #import"

var highlight_color:Color
var highlight_tag:String = ""
var overwrite_color:bool = false

func _init(tag, tag_data) -> void:
	highlight_tag = tag
	var keywords:String = tag_data.get("keyword", "any")
	
	var color = tag_data.get("color", Utils.DEFAULT_COLOR_STRING)
	highlight_color = Color.html(color)
	
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
	#var tag_idx = current_line_text.find(">"+highlight_tag)
	#if tag_idx > -1:
		#hl_info[tag_idx] = {"color":highlight_color}
		#hl_info[tag_idx + highlight_tag.length()+1] = hl_info[tag_idx-1]
		#needs_sort = true
	if not tagged_names.is_empty() and is_instance_valid(_tagged_name_regex):
		var _matches = _tagged_name_regex.search_all(current_line_text)
		for _match in _matches:
			var start_idx = _match.get_start(1)
			if not overwrite_color:
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
			hl_info[start_idx] = {"color": highlight_color}
	
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
		pattern_parts.append(Utils.URegex.escape_regex_meta_characters(str(name))) # Escape the name
	
	if not is_instance_valid(_tagged_name_regex):
		_tagged_name_regex = RegEx.new()
	
	var err = _tagged_name_regex.compile("\\b(" + "|".join(pattern_parts) + ")\\b")
	if err != OK:
		printerr("CustomHighlighter: Regex compilation error for imported consts: ", err)
		_tagged_name_regex.compile("(?!)")
