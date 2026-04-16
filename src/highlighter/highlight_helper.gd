@tool
extends RefCounted

const SPClasses = preload("res://addons/syntax_plus/src/utils/classes.gd")
const Utils = SPClasses.Utils
const HighlightLogic = SPClasses.HighlightLogic


var highlight_words:= {}
var _last_words_hash:int = -1
var _highlight_word_regex: RegEx # Dynamically built regex for these names
var declaration_regex: RegEx # To find "const NAME = xxx #import"

var highlight_color:Color
var highlight_tag:String = ""
var overwrite_color:bool = false

func _init(color:Color, tag:="", tag_data:={}) -> void:
	highlight_tag = tag
	highlight_color = color
	
	var overwrite = tag_data.get("overwrite", false)
	if overwrite is String:
		overwrite = overwrite.to_lower() == "true"
	overwrite_color = overwrite
	
	if highlight_tag != "":
		var keywords:String = tag_data.get("keyword", "any")
		var pattern = Utils.get_regex_pattern(keywords, tag)
		declaration_regex = RegEx.new()
		var err = declaration_regex.compile(pattern)
		if err != OK:
			printerr("CustomHighlighter: Regex compilation error for declaration_regex")
			declaration_regex.compile("(?!)")
	
	rebuild_tagged_name_regex() # Initialize with an empty regex


func check_line(hl_info, current_line_text): 
	var needs_sort = false
	if not highlight_words.is_empty() and is_instance_valid(_highlight_word_regex):
		var _matches = _highlight_word_regex.search_all(current_line_text)
		for _match in _matches:
			var start_idx = _match.get_start(1)
			if not overwrite_color:
				var index_data = hl_info.get(start_idx)
				if index_data == null:
					continue
				var existing_color = hl_info.get(start_idx, {}).get("color")
				if existing_color != HighlightLogic.default_text_color:
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

func set_highlight_words(new_words:Dictionary) -> bool:
	#var new_hash = new_words.hash()
	var words_changed = new_words != highlight_words
	if words_changed:
		highlight_words = new_words
		rebuild_tagged_name_regex()
	
	#_last_words_hash = new_hash
	return words_changed 

func rebuild_tagged_name_regex() -> void:
	_highlight_word_regex = Utils.build_name_regex(highlight_words.keys())
