@tool # hl
extends EditorSyntaxHighlighter

const EditorGDScriptParser = preload("res://addons/addon_lib/brohd/alib_editor/misc/parser/editor_parser.gd") #! resolve ALibEditor.Singletons.EditorGDScriptParser

const Utils = preload("res://addons/syntax_plus/src/gdscript/class/syntax_plus_utils.gd")
const EditorConfig = SyntaxPlusSingleton.EditorConfig

const HighlightLogic = preload("res://addons/syntax_plus/src/highlighter/highlighter_logic.gd")

var hl_logic:HighlightLogic
var active_code_edit:= false

func _get_name() -> String:
	return "SyntaxPlusV2"

func _init() -> void:
	print("INIT")
	print(get_text_edit())
	hl_logic = HighlightLogic.new()
	hl_logic.scanning_tags.connect(_on_scanning_tags)
	
	EditorGDScriptParser.get_instance().editor_script_changed.connect(_on_editor_script_changed)
	EditorGDScriptParser.get_instance().parse_completed.connect(_on_parse_completed)


func _on_editor_script_changed(new_script:Script):
	active_code_edit = false
	if not is_instance_valid(new_script):
		return
	
	active_code_edit = _is_current_code_edit()
	if not active_code_edit:
		return
	
	SyntaxPlusSingleton.notify_extensions(SyntaxPlusSingleton.ExtensionNoti.SCRIPT_CHANGED)
	_hl_logic_setup()

func _on_scanning_tags():
	SyntaxPlusSingleton.notify_extensions(SyntaxPlusSingleton.ExtensionNoti.TAG_SCAN) # SHOULD MOVE THIS OUT

func reset_highlighter():
	hl_logic.gdscript_parser.get_code_edit_parser().cache_dirty = true
	hl_logic.create_highlight_helpers()

func ensure_hl_logic_setup():
	if not is_instance_valid(hl_logic._text_edit):
		_hl_logic_setup()

func _hl_logic_setup():
	print("&*&*&*&*&*& ------- ")
	
	var current_script = ScriptEditorRef.get_current_script()
	hl_logic.script_resource = current_script # for creating a new one for each highlighter.
	# may be a good idea to do so it can run unhindered by the validating?
	
	var current_script_path = current_script.resource_path
	var gdscript_parser = EditorGDScriptParser.get_parser(current_script_path)
	hl_logic.set_gdscript_parser(gdscript_parser)
	
	
	var text_edit = get_text_edit()
	hl_logic.set_text_edit(text_edit)
	
	hl_logic.DummyHelper.set_code_edit()
	hl_logic.comment_tag_prefixes = SyntaxPlusSingleton.get_prefixes()
	SyntaxPlusSingleton.check_code_edit()
	hl_logic.init_scan_done = false




func get_gdscript_parser():
	return EditorGDScriptParser.get_parser()

func _on_parse_completed():
	if not active_code_edit:
		return
	#return
	hl_logic.update_class_members(true)
	print("&&& END &&&")

func _get_line_syntax_highlighting(line_idx: int) -> Dictionary:
	return hl_logic.get_line_syntax_highlighting(line_idx)









func _clear_highlighting_cache() -> void:
	#return
	#print("VIRTUAL CLEAR::", get_text_edit().get_line(0))
	return
	hl_logic.clear_highlighting_cache()

func _update_cache() -> void:
	if not _is_current_code_edit():
		return
	ensure_hl_logic_setup()
	#print("VIRTUAL CACHE::", get_text_edit().get_line(0))


func _is_current_code_edit() -> bool:
	var text_edit = get_text_edit()
	if not is_instance_valid(text_edit):
		return false
	var current_code_edit = ScriptEditorRef.get_current_code_edit()
	return current_code_edit == text_edit


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
