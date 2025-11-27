extends RefCounted

const Remote = preload("res://addons/syntax_plus/src/gdscript/class/syntax_plus_remote.gd")
const UFile = Remote.UFile #>remote
const URegex = Remote.URegex #>remote
const UClassDetail = Remote.UClassDetail
const ConfirmationDialogHandler = Remote.ConfirmationDialogHandler

const ANY_STRING = "const|var|@onready var|@export var|enum|class|func"
const TAG_CHAR = "#>"
const DEFAULT_COLOR_STRING = "35cc9b"
const DEFAULT_COLOR = Color(DEFAULT_COLOR_STRING)



enum MemberMode{
	NONE,
	ALL,
	INHERITED,
	SCRIPT,
}

enum RegExTarget{
	CONST_VAR,
	CLASS,
	FUNC,
	ENUM,
	ANY
}

static func set_script_highlighter(highlighter:="SyntaxPlus"):
	var script_editor = EditorInterface.get_script_editor().get_current_editor()
	var pop = EditorNodeRef.get_registered(EditorNodeRef.Nodes.SCRIPT_EDITOR_SYNTAX_POPUP) as PopupMenu
	if pop == null:
		return
	var id = -1
	for i in range(pop.item_count):
		var text = pop.get_item_text(i)
		if text != highlighter:
			pop.set_item_checked(i, false)
		else:
			id = pop.get_item_id(i)
			pop.set_item_checked(i, true)
	if id == -1:
		printerr("Error finding highlighter item: %s - \
Ensure open scripts have been reopened since enabling plugin. (Restart editor is quickest)" % highlighter)
	else:
		pop.id_pressed.emit(id)


static func reset_script_highlighters():
	var script_editor = EditorInterface.get_script_editor()
	var current_syntax = script_editor.get_current_editor().get_base_editor().syntax_highlighter
	if current_syntax.has_method("load_global_data"):
		current_syntax.load_global_data()
		current_syntax.read_editor_tags()
		current_syntax.create_highlight_helpers()
		current_syntax.clear_highlighting_cache()
	
	for script:ScriptEditorBase in script_editor.get_open_script_editors():
		var syntax = script.get_base_editor().syntax_highlighter
		if syntax.has_method("load_global_data"):
			syntax.read_editor_tags()
			syntax.create_highlight_helpers()
			syntax.clear_highlighting_cache()


static func sort_keys(hl_info:Dictionary):
	var sorted_keys = hl_info.keys()
	sorted_keys.sort()
	var temp_dict = {}
	for key in sorted_keys:
		temp_dict[key] = hl_info.get(key)
	return temp_dict


static func check_line_for_rebuild(line_text:String, line_text_last_state:String):
	if line_text.strip_edges(false, true) == "": # unsure of this with args
		return true
	if line_text.find(TAG_CHAR) > -1:
		return true
	if line_text_last_state.find(TAG_CHAR) > -1:
		return true
	var check_triggers = ["const ", "var ", "class ", "enum ", "func "]
	for trigger in check_triggers: ## Space at end for declaration
		if trigger in line_text:
			return true
	
	return false


static func get_all_class_members(script:GDScript=null):
	return UClassDetail.class_get_all_members(script).keys()


static func get_current_script_class():
	var script = EditorInterface.get_script_editor().get_current_script()
	if script != null:
		return script.get_instance_base_type()
	else: return ""

static func get_regex_pattern(keywords:String, tag):
	#if tag =="=MEMBER_HL":
		#return "^(?:@onready var|@export var|static var|var|const|class|enum|signal|func|static func)\\s+(\\w+)"
	if tag =="=MEMBER_HL": #^ new one accounts for exports
		return "^(?:@onready var|@export.*?\\s*var|static var|var|const|class|enum|signal|func|static func)\\s+(\\w+)"
	elif tag == "=CONST_HL":
		return "(?:const)\\s+([A-Z_0-9]+)\\s*[=:]" # const
	elif tag == "=CLASS_HL":
		return "(?:class|const|var)\\s+(?=[A-Z_0-9]*[a-z].*?[:=])([A-Z]\\w*)" # class
		# "(?:class|const|var)\\s+(?![A-Z_0-9]+\\s*[=:])([A-Z].*?)\\s*[=:]" #^ original
		# "(?:class|const|var)\\s+(?=[A-Z_0-9]*[a-z])([A-Z]\\w*)"
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
	
	var escaped_tag_char = URegex.escape_regex_meta_characters(TAG_CHAR)
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

static func _get_editor_setting(setting:String):
	var ed_s = EditorInterface.get_editor_settings()
	if ed_s.has_setting(setting):
		return ed_s.get_setting(setting)
	else:
		var default_val = Config.default_settings.get(setting)
		if setting.ends_with("color"):
			default_val = Color.html(default_val)
		ed_s.set_setting(setting, default_val)
		return ed_s.get_setting(setting)
		

static func _set_editor_setting(setting:String, val:Variant):
	EditorInterface.get_editor_settings().set_setting(setting, val)

static func _unset():
	for key in Config.default_settings.keys():
		_set_editor_setting(key, null)

static func set_editor_property_hints():
	var ed_settings = EditorInterface.get_editor_settings()
	ed_settings.add_property_info(Config.member_mode_propery_info) # set as enum

static func initial_set_editor_settings():
	var settings_array = [
		Config.set_as_default_highlighter,
		Config.const_color,
		Config.const_enable,
		Config.pascal_color,
		Config.pascal_enable,
		Config.onready_color,
		Config.onready_enable,
		Config.member_color,
		Config.member_enable,
		Config.member_highlight_mode,
		Config.member_access_color,
		Config.member_access_enable,
		Config.tag_color,
		Config.tag_color_enable,
	]
	var ed_settings = EditorInterface.get_editor_settings()
	for setting in settings_array:
		if ed_settings.has_setting(setting):
			continue
		var val = Config.default_settings.get(setting)
		if setting.ends_with("color"):
			val = Color.html(val)
		_set_editor_setting(setting, val)
	

static func get_tags_data():
	var ed_settings = EditorInterface.get_editor_settings()
	if not ed_settings.has_setting(Config.defined_tags):
		ed_settings.set_setting(Config.defined_tags, Config.default_tags.get("tags"))
	return ed_settings.get_setting(Config.defined_tags)


static func get_editor_config():
	var config = {}
	for key in Config.default_settings.keys():
		config[key] = _get_editor_setting(key)
	return config
	

static func get_pascal_hl_data():
	return {
		"color": _get_editor_setting(Config.pascal_color).to_html(),
		"keyword":"const|vars",
		"menu":"None",
		"overwrite":false
	}

static func get_const_hl_data():
	return {
		"color": _get_editor_setting(Config.const_color).to_html(),
		"keyword":"const",
		"menu":"None",
		"overwrite":false
	}

static func get_onready_hl_data():
	return {
		"color": _get_editor_setting(Config.onready_color).to_html(),
		"keyword":"@onready var",
		"menu":"None",
		"overwrite":false 
	}
	
 
static func get_member_hl_data():
	return {
		"color": _get_editor_setting(Config.member_color).to_html(),
		Config.member_highlight_mode: _get_editor_setting(Config.member_highlight_mode),
		"keyword":"@export var|@onready var|var|const|class",
		"menu":"None",
		"overwrite":false 
	}

class Config:
	const set_as_default_highlighter = "plugin/syntax_plus/set_as_default_highlighter"
	const pascal_enable = "plugin/syntax_plus/pascal/pascal_enable"
	const pascal_color = "plugin/syntax_plus/pascal/pascal_color"
	const const_enable = "plugin/syntax_plus/constant/constant_enable"
	const const_color = "plugin/syntax_plus/constant/constant_color"
	const onready_enable = "plugin/syntax_plus/onready/onready_enable"
	const onready_color = "plugin/syntax_plus/onready/onready_color"
	const member_enable = "plugin/syntax_plus/member/member_enable"
	const member_highlight_mode = "plugin/syntax_plus/member/member_highlight_mode"
	const member_color = "plugin/syntax_plus/member/member_color"
	const member_access_enable = "plugin/syntax_plus/member_access/member_access_enable"
	const member_access_color = "plugin/syntax_plus/member_access/member_access_color"
	const tag_color = "plugin/syntax_plus/tags/tag_color"
	const tag_color_enable = "plugin/syntax_plus/tags/tag_color_enable"
	const defined_tags = "plugin/syntax_plus/tags/defined_tags"
	
	const default_settings = {
		set_as_default_highlighter: false,
		pascal_enable: false,
		pascal_color: "28e0caff",
		const_enable: false,
		const_color: "2685ab",
		onready_enable: false,
		onready_color: "679c53ff",
		member_enable: true,
		member_highlight_mode: MemberMode.ALL,
		member_color: "bce0ff",
		member_access_enable: false,
		member_access_color: "91b8c4",
		tag_color: "5f9d9fff",
		tag_color_enable: true
	}
	
	const default_tags = {
	"tags": {
		"debug": {
			"color": "f7ff00",
			"keyword": "any",
			"menu": "Submenu",
			"overwrite": true
			}
		}
	}
	
	const member_mode_propery_info = {
	"name": Config.member_highlight_mode,
	"type": TYPE_INT,
	"hint": PROPERTY_HINT_ENUM,
	"hint_string": "NONE,ALL,INHERITED,SCRIPT"
}
