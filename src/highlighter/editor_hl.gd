@tool
extends EditorSyntaxHighlighter

const SPClasses = preload("res://addons/syntax_plus/src/utils/classes.gd")

const UtilsRemote = SPClasses.UtilsRemote
const EditorGDScriptParser = UtilsRemote.EditorGDScriptParser
const ScriptListManager = UtilsRemote.ScriptListManager

const EditorConfig = SPClasses.EditorConfig
const HighlightLogic = SPClasses.HighlightLogic

const CACHE_SIZE = 20

static var highlighter_history := {}

var hl_logic:HighlightLogic
var active_code_edit:= false

func _get_name() -> String:
	return "SyntaxPlusV2"

func _init() -> void:
	hl_logic = HighlightLogic.new()
	hl_logic.scanning_tags.connect(_on_scanning_tags)
	
	ScriptEditorRef.subscribe(ScriptEditorRef.Event.EDITOR_SCRIPT_CHANGED, _on_editor_script_changed)
	EditorGDScriptParser.get_instance().parse_completed.connect(_on_parse_completed)

func reset_highlighter():
	hl_logic.gdscript_parser.get_code_edit_parser().cache_dirty = true
	hl_logic.create_highlight_helpers()

func _on_scanning_tags():
	SyntaxPlusSingleton.notify_extensions(SyntaxPlusSingleton.ExtensionNoti.TAG_SCAN) # SHOULD MOVE THIS OUT

func _on_editor_script_changed(new_script:Script):
	active_code_edit = false
	if not is_instance_valid(new_script):
		return
	active_code_edit = _is_current_code_edit()
	if not active_code_edit:
		return
	
	_add_to_highlighter_history()
	
	SyntaxPlusSingleton.notify_extensions(SyntaxPlusSingleton.ExtensionNoti.SCRIPT_CHANGED)
	_hl_logic_setup()
	_clear_parser_cache()


func _hl_logic_setup():
	if hl_logic.default_text_color == Color.BLACK:
		print("YES BLACK")
		set_hl_logic_settings() # TEMP
	print("&*&*&*&*&*& ------- ")
	
	SyntaxPlusSingleton.check_code_edit()
	HighlightLogic.DummyHelper.set_code_edit()
	
	hl_logic.set_text_edit(get_text_edit())
	hl_logic.script_resource = _get_current_script()
	hl_logic.comment_tag_prefixes = SyntaxPlusSingleton.get_prefixes()
	
	#hl_logic.init_scan_done = false


func _on_parse_completed():
	if not active_code_edit:
		return
	#return
	hl_logic.update_class_members(true)

func update_highlighter():
	hl_logic.update_tagged_name_list(true)

func _get_line_syntax_highlighting(line_idx: int) -> Dictionary:
	if not is_instance_valid(hl_logic._text_edit):
		_hl_logic_setup()
	return hl_logic.get_line_syntax_highlighting(line_idx)


func _add_to_highlighter_history():
	if highlighter_history == null:
		highlighter_history = {}
	for ref in highlighter_history.keys():
		var ins = ref.get_ref()
		if not is_instance_valid(ins):
			highlighter_history.erase(ref)
			continue
		if ins == self:
			highlighter_history.erase(ref)
			break
	highlighter_history[weakref(self)] = true

func _clear_parser_cache():
	var current_size = highlighter_history.size()
	if current_size <= CACHE_SIZE:
		return
	
	var refs = highlighter_history.keys()
	var erased = 0
	while current_size - erased > CACHE_SIZE:
		var ref = refs.pop_front()
		var ins = ref.get_ref()
		ins.hl_logic.set_inactive()
		highlighter_history.erase(ref)
		erased += 1


func _is_current_code_edit() -> bool:
	var text_edit = get_text_edit()
	if not is_instance_valid(text_edit):
		return false
	var current_code_edit = ScriptEditorRef.get_current_code_edit()
	return current_code_edit == text_edit

func _get_current_script():
	return ScriptEditorRef.get_current_script()
	#var slm = ScriptListManager.get_instance()
	#var text_edit = get_text_edit()
	#var script_path = slm.script_editor_map.get(text_edit, "") as String
	#var current_script:GDScript # this whole thing may be unnecessary, get_current_script seems fine
	#if script_path == "":
		#current_script = ScriptEditorRef.get_current_script()
	#elif script_path.get_extension() == "gd":
		#current_script = load(script_path)
	#else:
		#printerr("ATTEMPT TO LOAD NON GD FILE WITH SYNTAXPLUS")
		#return
	#return current_script

static func set_hl_logic_settings():
	EditorConfig.load_data()
	
	var editor_settings = EditorInterface.get_editor_settings()
	HighlightLogic.default_text_color = editor_settings.get("text_editor/theme/highlighting/text_color")
	HighlightLogic.editor_member_color = editor_settings.get('text_editor/theme/highlighting/member_variable_color')
	
	HighlightLogic.const_enable = EditorConfig.get_setting(EditorConfig.Settings.CONST_ENABLE)
	HighlightLogic.const_color = EditorConfig.get_setting(EditorConfig.Settings.CONST_COLOR)
	HighlightLogic.pascal_enable = EditorConfig.get_setting(EditorConfig.Settings.PASCAL_ENABLE)
	HighlightLogic.pascal_color = EditorConfig.get_setting(EditorConfig.Settings.PASCAL_COLOR)
	HighlightLogic.member_enable = EditorConfig.get_setting(EditorConfig.Settings.MEMBER_ENABLE)
	HighlightLogic.member_color = EditorConfig.get_setting(EditorConfig.Settings.MEMBER_COLOR)
	HighlightLogic.member_access_enable = EditorConfig.get_setting(EditorConfig.Settings.MEMBER_ACCESS_ENABLE)
	HighlightLogic.member_access_color = EditorConfig.get_setting(EditorConfig.Settings.MEMBER_ACCESS_COLOR)
	HighlightLogic.inh_member_enable = EditorConfig.get_setting(EditorConfig.Settings.INHERITED_MEMBER_ENABLE)
	HighlightLogic.inh_member_color = EditorConfig.get_setting(EditorConfig.Settings.INHERITED_MEMBER_COLOR)
	HighlightLogic.base_type_member_enable = EditorConfig.get_setting(EditorConfig.Settings.BASE_TYPE_MEMBER_ENABLE)
	HighlightLogic.base_type_member_color = EditorConfig.get_setting(EditorConfig.Settings.BASE_TYPE_MEMBER_COLOR)
	HighlightLogic.inner_class_member_enable = EditorConfig.get_setting(EditorConfig.Settings.INNER_CLASS_MEMBER_ENABLE)
	HighlightLogic.inner_class_member_color = EditorConfig.get_setting(EditorConfig.Settings.INNER_CLASS_MEMBER_COLOR)
	
	HighlightLogic.tag_color = EditorConfig.get_setting(EditorConfig.Settings.TAG_COLOR)
	HighlightLogic.tag_enable = EditorConfig.get_setting(EditorConfig.Settings.TAG_COLOR_ENABLE)
	HighlightLogic.editor_tags = EditorConfig.get_tags_data()
