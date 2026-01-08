extends RefCounted

const UString = preload("res://addons/addon_lib/brohd/alib_runtime/utils/src/u_string.gd")
const UNCOLORED_BG = Color(0,0,0,0)

const PREFIX = "#!"
const TAG = "ensure-path"
const FULL_TAG = PREFIX + " " + TAG

var settings_helper:ALibEditor.SettingHelper

var _completion_tags_added:=false

var valid_color:Color
var invalid_color:Color
var invalid_bg_color:Color

var watched_scripts = {}
var current_script_path:String = ""

func _init() -> void:
	settings_helper = ALibEditor.SettingHelper.new(self)
	settings_helper.subscribe(&"valid_color", Settings.VALID_COLOR, Settings.COLOR_VALID)
	settings_helper.subscribe(&"invalid_color", Settings.INVALID_COLOR, Settings.COLOR_INVALID)
	settings_helper.subscribe(&"invalid_bg_color", Settings.INVALID_BG_COLOR, Settings.COLOR_INVALID_BG)
	settings_helper.initialize()
	
	
	SyntaxPlus.register_highlight_callable(PREFIX, TAG, _highlight_line, SyntaxPlus.CallableLocation.END)
	
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_on_filesystem_changed)
	
	ScriptEditorRef.subscribe(ScriptEditorRef.Event.VALIDATE_SCRIPT, _on_validate_script)
	EditorCodeCompletion.call_on_ready(_add_tags)

func _add_tags():
	_completion_tags_added = true
	EditorCodeCompletion.register_tag_static(PREFIX, TAG, EditorCodeCompletion.TagLocation.END)

func _unregister_tags():
	if _completion_tags_added:
		EditorCodeCompletion.unregister_tag_static(PREFIX, TAG)

func syntax_plus_notification(what:int):
	if what == 1:
		_on_editor_script_changed()

func _highlight_line(script_editor:CodeEdit, current_line_text:String, line:int, comment_tag_idx:int):
	if not watched_scripts.has(current_script_path):
		watched_scripts[current_script_path] = {Keys.INVALID_LINES:{}, Keys.LINE_DATA:{}}
	
	watched_scripts[current_script_path][Keys.INVALID_LINES].erase(line)
	var valid = _validate_paths_in_line(line)
	if valid:
		return {0 : SyntaxPlus.get_hl_info_dict(valid_color)}
	else:
		watched_scripts[current_script_path][Keys.INVALID_LINES][line] = true
		return {0 : SyntaxPlus.get_hl_info_dict(invalid_color)}

func _on_validate_script():
	_set_background_colors()

func _set_background_colors():
	var script_editor = ScriptEditorRef.get_current_code_edit()
	var invalid_lines = watched_scripts.get(current_script_path, {}).get(Keys.INVALID_LINES, {})
	for idx in invalid_lines.keys():
		var valid = _validate_paths_in_line(idx)
		if valid:
			continue
		var existing_color = script_editor.get_line_background_color(idx)
		if existing_color != UNCOLORED_BG:
			continue
		script_editor.set_line_background_color(idx, invalid_bg_color)


func _validate_paths_in_line(line:int):
	var data = watched_scripts[current_script_path][Keys.LINE_DATA].get(line)
	var script_editor = ScriptEditorRef.get_current_code_edit()
	var current_line_text = script_editor.get_line(line)
	if current_line_text.find(FULL_TAG) == -1:
		watched_scripts[current_script_path][Keys.LINE_DATA].erase(line)
		return true
	var paths
	if data != null:
		var text = data.get(Keys.LINE_TEXT)
		if text == current_line_text:
			paths = data.get(Keys.PATHS)
	if paths == null:
		paths = UString.get_paths_in_line(current_line_text)
		watched_scripts[current_script_path][Keys.LINE_DATA][line] = {
			Keys.LINE_TEXT: current_line_text,
			Keys.PATHS: paths
		}
	if paths.is_empty():
		return false
	for path in paths:
		if not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path):
			return false
	return true


func _on_filesystem_changed():
	_invalidate_current()

func _on_editor_script_changed():
	current_script_path = ""
	var current_script = ScriptEditorRef.get_current_script()
	if not is_instance_valid(current_script):
		return
	current_script_path = current_script.resource_path
	_invalidate_current()

func _invalidate_current():
	if watched_scripts.has(current_script_path):
		var script_data = watched_scripts.get(current_script_path)
		for line in watched_scripts[current_script_path][Keys.LINE_DATA].keys():
			SyntaxPlus.clear_cache(line)
		_set_background_colors()
		watched_scripts.erase(current_script_path)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_unregister_tags()

class Keys:
	const LINE_DATA = &"LINE_DATA"
	const INVALID_LINES = &"INVALID_LINES"
	const LINE_TEXT = &"LINE_TEXT"
	const PATHS = &"PATHS"

class Settings:
	const VALID_COLOR = &"plugin/syntax_plus/extensions/ensure_path/valid_color"
	const INVALID_COLOR = &"plugin/syntax_plus/extensions/ensure_path/invalid_color"
	const INVALID_BG_COLOR = &"plugin/syntax_plus/extensions/ensure_path/invalid_background_color"
	
	const COLOR_VALID = Color(0.086, 0.604, 0.384)
	const COLOR_INVALID = Color(1.0, 0.524, 0.476)
	const COLOR_INVALID_BG = Color(0.4, 0.0, 0.0, 0.463)
