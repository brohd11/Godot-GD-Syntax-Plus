const SPClasses = preload("res://addons/syntax_plus/src/utils/classes.gd")
const UtilsRemote = preload("res://addons/syntax_plus/src/utils/utils_remote.gd")
const URegex = UtilsRemote.URegex #>remote


const ANY_STRING = "const|var|@onready var|@export var|enum|class|func"
const TAG_CHAR = ">"
const FULL_TAG_CHAR = "#" + TAG_CHAR
const DEFAULT_COLOR = Color("35cc9b")


enum RegExTarget{
	CONST_VAR,
	CLASS,
	FUNC,
	ENUM,
	ANY
}

static func build_name_regex(name_array:Array, tag_hl:=false):
	var regex = RegEx.new()
	if name_array.is_empty():
		if is_instance_valid(regex): # Check if already created
			regex.compile("(?!)") # Non-matching regex
		else:
			regex = RegEx.new()
			regex.compile("(?!)")
		return
	
	var pattern_parts = []
	for name in name_array:
		pattern_parts.append(URegex.escape_regex_meta_characters(str(name))) # Escape the name
	
	if not is_instance_valid(regex):
		regex = RegEx.new()
	var err
	if tag_hl:
		err = regex.compile("(?:#)?(" + "|".join(pattern_parts) + ")\\b")
	else:
		err = regex.compile("\\b(" + "|".join(pattern_parts) + ")\\b")
	if err != OK:
		printerr("CustomHighlighter: Regex compilation error: %s - Names:\n%s" % [err, " ".join(name_array)])
		regex.compile("(?!)")
	
	return regex


static func get_regex_pattern(keywords:String, tag):
	if tag == "":
		return "(?!)"
	if tag =="=MEMBER_HL": #^ new one accounts for exports
		return "^(?:@onready var|@export.*?\\s*var|static var|var|const|class|enum|signal|func|static func)\\s+(\\w+)"
	elif tag == "=CONST_HL":
		return "(?:const)\\s+([A-Z_0-9]+)\\s*[=:]" # const
	elif tag == "=CLASS_HL":
		return "(?:class|const|var)\\s+(?=[A-Z_0-9]*[a-z].*?[:=])([A-Z]\\w*)" # class
	elif tag == "=ONREADY_HL":
		return "(?:@onready var)\\s+([a-z_].*?)\\s*[=:]"
	
	var regex_target = RegExTarget.CONST_VAR
	keywords = keywords.to_lower()
	if keywords == "any":
		regex_target = RegExTarget.ANY
		keywords = ANY_STRING
	if regex_target != RegExTarget.ANY:
		var keywords_array: PackedStringArray = keywords.split("|")
		var has_const_or_var = false
		var has_class = false
		var has_func = false
		var has_enum = false
		for keyword in keywords_array:
			if keyword == "func":
				has_func = true
			if keyword == "class":
				has_class = true
			if keyword == "enum":
				has_enum = true
			if keyword == "const" or keyword == "var":
				has_const_or_var = true
		if keywords.count("vars") == 1 and keywords.find("@onready") == -1 and keywords.find("@export") == -1:
			keywords = keywords.replace("vars", "@onready var|@export var|var")
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
			escaped_keywords_parts.append(URegex.escape_regex_meta_characters(keyword_part))
	var combined_keywords_pattern: String
	if escaped_keywords_parts.is_empty():
		printerr("No valid keywords provided for regex.")
		return "(?!)"
	elif escaped_keywords_parts.size() == 1:
		combined_keywords_pattern = escaped_keywords_parts[0] # No need for group or | if only one
	else:
		combined_keywords_pattern = "(?:" + "|".join(escaped_keywords_parts) + ")"
	
	var escaped_tag_char = URegex.escape_regex_meta_characters(FULL_TAG_CHAR)
	var escaped_tag = URegex.escape_regex_meta_characters(tag)
	
	var pattern = "(?!)" # (?:#\\s*) == allows to see tags in comments
	if regex_target == RegExTarget.CONST_VAR: 
		pattern = "^\\s*(?:(?:#\\s*)?static\\s+|#\\s*)?" + combined_keywords_pattern + "\\s+([a-zA-Z_][a-zA-Z0-9_]*)(?:\\s*:\\s*\\S+)?(?:\\s*(?:=|:=)\\s*.*?)?\\s*" + escaped_tag_char + "\\s*" + escaped_tag + "(?:\\s|$)"
	elif regex_target == RegExTarget.CLASS:
		pattern = "^\\s*(?:#)?class\\s+([A-Za-z_][A-Za-z0-9_]*)(?:\\s+extends\\s+(?:[A-Za-z_][A-Za-z0-9_.]*|\"[^\"]*\"))?\\s*:\\s*.*?" + escaped_tag_char + "\\s*" + escaped_tag + "(?:\\s|$)"
	elif regex_target == RegExTarget.FUNC:
		pattern = "^\\s*(?:(?:#\\s*)?static\\s+|#\\s*)?func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(.*?\\)(?:\\s*->\\s*\\S+)?\\s*:.*?" + escaped_tag_char + "\\s*" + escaped_tag + "(?:\\s|$)"
	elif regex_target == RegExTarget.ENUM:
		pattern = "^\\s*(?:#)?enum\\s+([a-zA-Z_][a-zA-Z0-9_]*)(?:\\s*\\{.*?\\}|\\s*\\{|\\s*:)\\s*" + escaped_tag_char + "\\s*" + escaped_tag + "(?:\\s|$)"
	elif regex_target == RegExTarget.ANY: #CHONKER
		pattern = (
			"^\\s*(?:(?:#\\s*)?static\\s+|#\\s*)?" +                                  # Start of line, optional leading whitespace
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
				"(?:\\s*(?:extends\\s+\\S+)?\\s*:)" + # Matches optional 'extends Something' then a colon # parser -> ""
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
			
			"\\s*" + escaped_tag_char + "\\s*" +                              # Whitespace, '#', whitespace (for the comment start)
			escaped_tag +      # CAPTURE GROUP 2: The tag itself
			"(?:\\s|$)"                                # Trailing whitespace or end of line
			)
	
	return pattern
