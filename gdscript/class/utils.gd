extends RefCounted

const JSON_PATH = "res://addons/syntax_tags/tags.json"

const ANY_STRING = "const|var|@onready var|@export var|enum|class|func"

enum RegExTarget{
	CONST_VAR,
	CLASS,
	FUNC,
	ENUM,
	ANY
}

static func escape_regex_meta_characters(text: String, strip_symbols=false) -> String:
	if strip_symbols:
		if text.find("(") > -1:
			text = text.replace("(", "")
		if text.find(")") > -1:
			text = text.replace(")", "")
	var output: PackedStringArray = []
	for char_str in text:
		match char_str:
			".", "+", "*", "?", "^", "$", "(", ")", "[", "]", "{", "}", "|", "\\":
				output.append("\\" + char_str)
			_:
				output.append(char_str)
	return "".join(output)

static func sort_keys(hl_info:Dictionary):
	var sorted_keys = hl_info.keys()
	sorted_keys.sort()
	var temp_dict = {}
	for key in sorted_keys:
		temp_dict[key] = hl_info.get(key)
	hl_info = temp_dict
	
	return hl_info

static func read_from_json(path:String,access=FileAccess.READ) -> Dictionary:
	var json_read = JSON.new()
	var json_load = FileAccess.open(path, access)
	if json_load == null:
		print("Couldn't load JSON: ", path)
		return {}
	var json_string = json_load.get_as_text()
	var err = json_read.parse(json_string)
	if err != OK:
		print("Couldn't load JSON, error: ", err)
		return {}
	
	return json_read.data

static func write_to_json(data:Variant,path:String,access=FileAccess.WRITE_READ) -> void:
	var data_string = JSON.stringify(data,"\t")
	var json_file = FileAccess.open(path, access)
	json_file.store_string(data_string)

static func get_regex_pattern(keywords:String, tag):
	var regex_target = RegExTarget.CONST_VAR
	keywords = keywords.to_lower()
	if keywords == "any":
		regex_target = RegExTarget.ANY
		keywords = ANY_STRING
	if regex_target != RegExTarget.ANY:
		var has_const_or_var = false
		var has_class = false
		var has_func = false
		var has_enum = false
		if keywords.find("func") > -1:
			has_func = true
		if keywords.find("class") > -1:
			has_class = true
		if keywords.find("enum") > -1:
			has_enum = true
		if keywords.find("const") > -1 or keywords.find("var") > -1:
			has_const_or_var = true
		if keywords.count("var") == 1 and keywords.find("@onready") == -1 and keywords.find("@export") == -1:
			keywords = keywords.replace("var", "var|@onready var|@export var")
		if int(has_func) + int(has_class) + int(has_enum) > 1:
			regex_target = RegExTarget.ANY
		elif has_func:
			regex_target = RegExTarget.FUNC
		elif has_class:
			regex_target = RegExTarget.CLASS
		elif has_enum:
			regex_target = RegExTarget.ENUM
		if has_const_or_var:
			if regex_target != RegExTarget.ANY and regex_target != RegExTarget.CONST_VAR:
				regex_target = RegExTarget.ANY
			elif regex_target != RegExTarget.ANY:
				regex_target = RegExTarget.CONST_VAR
	
	var keywords_array: PackedStringArray = keywords.split("|")
	var escaped_keywords_parts: Array = []
	for keyword_part in keywords_array:
		if not keyword_part.is_empty(): # Avoid issues with empty strings if input is like "var||const"
			escaped_keywords_parts.append(escape_regex_meta_characters(keyword_part))
	var combined_keywords_pattern: String
	if escaped_keywords_parts.is_empty():
		printerr("No valid keywords provided for regex.")
		return "(?!)"
	elif escaped_keywords_parts.size() == 1:
		combined_keywords_pattern = escaped_keywords_parts[0] # No need for group or | if only one
	else:
		combined_keywords_pattern = "(?:" + "|".join(escaped_keywords_parts) + ")"
	
	var escaped_tag = escape_regex_meta_characters(tag)
	
	var pattern = "(?!)"
	if regex_target == RegExTarget.CONST_VAR:
		pattern = "^\\s*" + combined_keywords_pattern + "\\s+([a-zA-Z_][a-zA-Z0-9_]*)(?:\\s*:\\s*\\S+)?(?:\\s*(?:=|:=)\\s*.*?)?\\s*#\\s*" + escaped_tag + "(?:\\s|$)"
	elif regex_target == RegExTarget.CLASS:
		pattern = "^\\s*class\\s+([A-Za-z_][A-Za-z0-9_]*)(?:\\s+extends\\s+(?:[A-Za-z_][A-Za-z0-9_]*|\"[^\"]*\"))?\\s*:\\s*.*?" + escaped_tag
	elif regex_target == RegExTarget.FUNC:
		pattern = "^\\s*func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(.*?\\)(?:\\s*->\\s*\\S+)?\\s*:.*?#\\s*(" + escaped_tag + ")(?:\\s|$)"
	elif regex_target == RegExTarget.ENUM:
		pattern = "^\\s*enum\\s+([a-zA-Z_][a-zA-Z0-9_]*)(?:\\s*\\{.*?\\}|\\s*\\{|\\s*:)\\s*#\\s*(" + escaped_tag + ")(?:\\s|$)"
	elif regex_target == RegExTarget.ANY: #CHONKER
		pattern = (
			"^\\s*" +                                  # Start of line, optional leading whitespace
			combined_keywords_pattern +                # Your combined keywords
			"\\s+" +                                   # One or more spaces after the keyword
			"([a-zA-Z_][a-zA-Z0-9_]*)" +               # CAPTURE GROUP 1: The name
			
			# Non-capturing group for the varying syntax between name and the '#tag'
			# Order matters: more specific/longer patterns first.
			"(?:" +
				# ---- BRANCH 1: Function signature (params, return type, colon) ----
				"(?:\\s*\\(.*?\\)(?:\\s*->\\s*\\S+)?\\s*:)" +
			"|" +
				# ---- BRANCH 2: Class definition with optional 'extends' ----
				# This needs to be before simple colon match if colon is part of extends
				"(?:\\s*(?:extends\\s+\\S+)?\\s*:)" + # Matches optional 'extends Something' then a colon
			"|" +
				# ---- BRANCH 3: Enum with inline body, tag is AFTER this structure `enum E {...} #tag` ----
				"(?:\\s*\\{.*?\\})" + # Non-greedy match for content within {}, then \s*#tag follows
			"|" +
				# ---- BRANCH 4: Enum with tag immediately after opening brace `enum E{ #tag` ----
				"(?:\\s*\\{)" + # Matches up to the opening brace
			"|" +
				# ---- BRANCH 5: Class (without extends) or Enum with simple colon (e.g., "enum E:") ----
				# This is a simpler colon match, placed after more complex colon patterns
				"(?:\\s*:)" +
			"|" +
				# ---- BRANCH 6: Variable/Constant specifics (type hint, assignment OR NOTHING for "var x #tag") ----
				"(?:(?:\\s*:\\s*\\S+)?(?:\\s*(?:=|:=)\\s*.*?)?)" +
			")" +
			
			"\\s*#\\s*" +                              # Whitespace, '#', whitespace (for the comment start)
			"(" + escaped_tag + ")" +      # CAPTURE GROUP 2: The tag itself
			"(?:\\s|$)"                                # Trailing whitespace or end of line
			)
	
	return pattern
