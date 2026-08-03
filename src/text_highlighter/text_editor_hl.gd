@tool
extends EditorSyntaxHighlighter
#! remote

const Dispatcher = preload("res://addons/addon_lib/brohd/alib_runtime/misc/syntax_highlighters/text/dispatcher.gd")
const Palette = preload("res://addons/addon_lib/brohd/alib_runtime/misc/syntax_highlighters/text/palette.gd")

## per-type highlighter for the edited file, or null when the extension is unhandled
var _highlighter
var _palette
## guard against re-resolving on every line when the extension has no highlighter
var _synced := false


func _get_name() -> String:
	return "SyntaxPlusText"

static func get_supported_languages():
	return Dispatcher.get_supported_extensions()

func _get_supported_languages() -> PackedStringArray:
	return get_supported_languages()


func _get_line_syntax_highlighting(line:int) -> Dictionary:
	_sync()
	if _highlighter == null:
		return {}
	return _highlighter.get_line_highlighting(line)


func _clear_highlighting_cache() -> void:
	if _highlighter != null:
		_highlighter.clear_cache()

func _update_cache() -> void:
	_palette = null
	_synced = false


func _sync() -> void:
	if _synced:
		return
	_synced = true
	
	var slm = ALibEditor.Singleton.ScriptListManager.get_instance()
	var path = slm.get_current_item_data().get(slm.Keys.TOOLTIP)
	
	if _palette == null:
		_palette = Palette.from_editor_settings()

	_highlighter = Dispatcher.get_highlighter(path)
	if _highlighter != null:
		_highlighter.setup(get_text_edit(), _palette)
