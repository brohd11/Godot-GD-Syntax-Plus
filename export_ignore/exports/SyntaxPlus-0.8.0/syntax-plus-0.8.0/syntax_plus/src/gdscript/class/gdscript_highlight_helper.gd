@tool
extends RefCounted

const Utils = preload("res://addons/syntax_plus/src/gdscript/class/syntax_plus_utils.gd") #>import utils.gd
const GDHelper = preload("res://addons/syntax_plus/src/gdscript/editor/gdscript_helper.gd")  #>import gdscript_helper.gd

var tagged_names: Dictionary = {} # Stores the names of consts marked for special highlighting
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
	_tagged_name_regex = Utils.build_name_regex(tagged_names.keys())

