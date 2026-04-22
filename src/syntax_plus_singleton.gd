class_name SyntaxPlusSingleton
extends SingletonRefCount
const SingletonRefCount = Singleton.RefCount

const SCRIPT = preload("res://addons/syntax_plus/src/syntax_plus_singleton.gd")

const SPClasses = preload("res://addons/syntax_plus/src/utils/classes.gd")

const Utils = SPClasses.Utils
const EditorHL = SPClasses.EditorHL
const HLInfo = SPClasses.HLInfo
const EditorConfig = SPClasses.EditorConfig

const UtilsRemote = SPClasses.UtilsRemote
const UClassDetail = UtilsRemote.UClassDetail

# deps
const CONTEXT_PLUGINS = [
	preload("res://addons/syntax_plus/src/editor_plugins/syntax_tag_context_menu.gd")
]
const SYNTAX_HIGHLIGHTERS = [
	EditorHL
]

const CommentHighlightExt = preload("res://addons/syntax_plus/src/extensions/comment_highlight.gd")
const EnsurePathExt = preload("res://addons/syntax_plus/src/extensions/ensure_path.gd")

enum CallableLocation {
	START,
	END,
	ANY,
}

enum ExtensionNoti {
	TAG_SCAN,
	SCRIPT_CHANGED,
}


static func get_singleton_name() -> String:
	return "SyntaxPlusSingleton"

static func get_instance() -> SyntaxPlusSingleton:
	return _get_instance(SCRIPT)

static func instance_valid() -> bool:
	return _instance_valid(SCRIPT)

static func register_node(node:Node):
	return _register_node(SCRIPT, node)

static func unregister_node(node):
	_unregister_node(SCRIPT, node)

static func call_on_ready(callable, print_err:bool=true):
	_call_on_ready(SCRIPT, callable, print_err)

#region Highlight Helper Funcs

var default_text_color:Color
var editor_member_color:Color
var comment_color:Color
var annotation_color:Color
var symbol_color:Color
var number_color:Color
var keyword_color:Color
var control_flow_color:Color
var function_color:Color
var global_function_color:Color
var base_type_color:Color
var engine_type_color:Color
var user_type_color:Color
var string_color:Color
var string_name_color:Color
var node_path_color:Color
var node_reference_color:Color

var single_line_code_edit:CodeEdit
var single_line_gdscript_highlighter: GDScriptSyntaxHighlighter

static func set_default_text_colors():
	var instance = get_instance()
	var editor_settings = EditorInterface.get_editor_settings()
	instance.default_text_color = editor_settings.get(&"text_editor/theme/highlighting/text_color")
	instance.editor_member_color = editor_settings.get(&"text_editor/theme/highlighting/member_variable_color")
	instance.comment_color = editor_settings.get_setting(&"text_editor/theme/highlighting/comment_color")
	instance.annotation_color = editor_settings.get_setting(&"text_editor/theme/highlighting/gdscript/annotation_color")
	instance.symbol_color = editor_settings.get_setting(&"text_editor/theme/highlighting/symbol_color")
	instance.number_color = editor_settings.get_setting(&"text_editor/theme/highlighting/number_color")
	instance.keyword_color = editor_settings.get_setting(&"text_editor/theme/highlighting/keyword_color")
	instance.control_flow_color = editor_settings.get_setting(&"text_editor/theme/highlighting/control_flow_keyword_color")
	instance.function_color = editor_settings.get_setting(&"text_editor/theme/highlighting/function_color")
	instance.global_function_color = editor_settings.get_setting(&"text_editor/theme/highlighting/gdscript/global_function_color")
	instance.base_type_color = editor_settings.get_setting(&"text_editor/theme/highlighting/base_type_color")
	instance.engine_type_color = editor_settings.get_setting(&"text_editor/theme/highlighting/engine_type_color")
	instance.user_type_color = editor_settings.get_setting(&"text_editor/theme/highlighting/user_type_color")
	instance.string_color = editor_settings.get_setting(&"text_editor/theme/highlighting/string_color")
	instance.string_name_color = editor_settings.get_setting(&"text_editor/theme/highlighting/gdscript/string_name_color")
	instance.node_path_color = editor_settings.get_setting(&"text_editor/theme/highlighting/gdscript/node_path_color")
	instance.node_reference_color = editor_settings.get_setting(&"text_editor/theme/highlighting/gdscript/node_reference_color")

static func check_code_edit():
	var instance = get_instance()
	if not is_instance_valid(instance.single_line_gdscript_highlighter):
		instance.single_line_gdscript_highlighter = GDScriptSyntaxHighlighter.new()
	if not is_instance_valid(instance.single_line_code_edit):
		instance.single_line_code_edit = CodeEdit.new()
		instance.single_line_code_edit.highlight_current_line = false
		instance.single_line_code_edit.syntax_highlighter = instance.single_line_gdscript_highlighter
		EditorInterface.get_base_control().add_child(instance.single_line_code_edit) 
		EditorInterface.get_base_control().remove_child(instance.single_line_code_edit)

static func get_single_line_highlight(text:String) -> Dictionary:
	var instance = get_instance()
	instance.single_line_code_edit.set_line(0, text)
	var hl_info = instance.single_line_gdscript_highlighter.get_line_syntax_highlighting(0)
	return hl_info.duplicate()


#endregion

var extensions:= []

func _add_extensions():
	extensions = []
	var exts = [
		CommentHighlightExt,
		EnsurePathExt
	]
	
	for e in exts:
		var ins = e.new()
		extensions.append(ins)
	
	update_comment_tags()

static func notify_extensions(what:ExtensionNoti):
	var instance = get_instance()
	for ext in instance.extensions:
		if ext.has_method("syntax_plus_notification"):
			ext.syntax_plus_notification(what)


#region Comment Tags


static func register_comment_tag(prefix:String, tag:String, color:Color=Color.GOLDENROD):
	var instance = get_instance()
	if not instance.comment_tag_data.has(prefix):
		instance.comment_tag_data[prefix] = {}
	if instance.comment_tag_data[prefix].has(tag):
		print("Already have comment tag registered: %s" % tag)
		return
	instance.comment_tag_data[prefix][tag] = {"color": color}
	instance.update_comment_tags()

static func unregister_comment_tag(prefix:String, tag:String):
	var instance = get_instance()
	if not instance.comment_tag_data.has(prefix):
		print("Comment tag not registered: %s" % tag)
		return
	if instance.comment_tag_data[prefix].has(tag):
		instance.comment_tag_data[prefix].erase(tag)
		if instance.comment_tag_data[prefix].is_empty():
			instance.comment_tag_data.erase(prefix)
		instance.update_comment_tags()
		return
	print("Comment tag not registered: %s" % tag)

static func get_comment_tag_data():
	var instance = get_instance()
	return instance.comment_tag_data

static func get_comment_tags():
	var instance = get_instance()
	return instance.comment_tags

#endregion

## Register a callable to highlight lines where prefix and tag are found. Callable should take args:
## (script_editor:CodeEdit, current_line_text:String, line_idx:int, comment_tag_idx:int)
static func register_highlight_callable(prefix:String, tag:String, callable:Callable, callable_location:=CallableLocation.START):
	var instance = get_instance()
	if not instance.highlight_callable_data.has(prefix):
		instance.highlight_callable_data[prefix] = {}
	if instance.highlight_callable_data[prefix].has(tag):
		print("Already have highlight callable registered: %s" % tag)
		return
	instance.highlight_callable_data[prefix][tag] = {"callable":callable, "callable_location":callable_location}
	instance.update_comment_tags()


static func unregister_highlight_callable(prefix:String, tag:String):
	var instance = get_instance()
	if not instance.highlight_callable_data.has(prefix):
		print("Highlight callable not registered: %s" % tag)
		return
	if instance.highlight_callable_data[prefix].has(tag):
		instance.highlight_callable_data[prefix].erase(tag)
		if instance.highlight_callable_data[prefix].is_empty():
			instance.highlight_callable_data.erase(prefix)
			instance.update_comment_tags()
		return
	print("Highlight callable not registered: %s" % tag)

static func get_highlight_callables():
	var instance = get_instance()
	return instance.highlight_callable_data

static func get_prefixes():
	var instance = get_instance()
	return instance.comment_tag_prefixes

static func get_prefix_color(prefix):
	var instance = get_instance()
	return instance.prefix_colors.get(prefix)

static func set_prefix_color(prefix:String, color:Color):
	var instance = get_instance()
	instance.prefix_colors[prefix] = color

var editor_plugin_manager:EditorPluginManager

var prefix_colors = {}
var comment_tag_prefixes = []
var comment_tags = {}
var comment_tag_data = {}
var highlight_callable_data = {}

const DEFAULT_TAG_COLOR = Color.GOLDENROD

static func update_comment_tags():
	var instance = get_instance()
	var prefixes = {}
	for prefix in instance.comment_tag_data.keys():
		prefixes[prefix] = true
		var tag_dict = instance.comment_tag_data.get(prefix, {})
		var tag_array = tag_dict.keys()
		instance.comment_tags[prefix] = tag_array
	for prefix in instance.highlight_callable_data.keys():
		prefixes[prefix] = true
	
	instance.comment_tag_prefixes = prefixes.keys()

#region Misc Api


static func invalidate_line(line:=-1):
	var hl = ScriptEditorRef.get_current_code_edit().syntax_highlighter
	if hl is EditorHL:
		hl.hl_logic.invalidate(line)

static func get_hl_info_dict(color:Color) -> Dictionary:
	return {"color": color}



	

#endregion


func _all_unregistered_callback():
	if is_instance_valid(editor_plugin_manager):
		editor_plugin_manager.remove_plugins()
		editor_plugin_manager.plugin.queue_free()

func _init(node) -> void:
	EditorConfig.initialize()

func _ready() -> void:
	EditorHL.set_hl_logic_settings()
	EditorNodeRef.call_on_ready(_connect_on_editor_node_ref_ready)
	EditorInterface.get_editor_settings().settings_changed.connect(_on_editor_settings_changed, 1)

func _connect_on_editor_node_ref_ready():
	ScriptEditorRef.get_instance().editor_script_changed.connect(_on_editor_script_changed, 1)
	set_default_text_colors()
	_add_plugins()
	_add_extensions.call_deferred()

func _add_plugins():
	var ed_plug = EditorPlugin.new()
	add_child(ed_plug)
	editor_plugin_manager = EditorPluginManager.new(ed_plug)
	editor_plugin_manager.context_menu_plugin_paths = CONTEXT_PLUGINS
	editor_plugin_manager.syntax_highlighter_paths = SYNTAX_HIGHLIGHTERS
	editor_plugin_manager.add_plugins.call_deferred()



func _on_editor_script_changed(script:Script) -> void:
	if script == null:
		return
	if script.resource_path.get_extension() != "gd":
		return
	if EditorInterface.get_script_editor().get_current_editor() == null:
		return
	if EditorConfig.get_setting(EditorConfig.Settings.SET_AS_DEFAULT_HIGHLIGHTER):
		var code_edit = ScriptEditorRef.get_current_code_edit()
		if code_edit.syntax_highlighter is not EditorHL:
			set_script_highlighter()

func _on_editor_settings_changed():
	EditorConfig.load_data()
	reset_script_highlighters()


static func set_script_highlighter(highlighter:="SyntaxPlus"):
	var pop = EditorNodeRef.get_registered(EditorNodeRef.Nodes.SCRIPT_EDITOR_SYNTAX_POPUP, false)
	if not is_instance_valid(pop):
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
	EditorHL.set_hl_logic_settings()
	
	var script_editor = EditorInterface.get_script_editor()
	#var current_syntax = script_editor.get_current_editor().get_base_editor().syntax_highlighter
	#if current_syntax.has_method("load_global_data"):
		#current_syntax.create_highlight_helpers()
		##current_syntax.clear_highlighting_cache()
	#
	for script:ScriptEditorBase in script_editor.get_open_script_editors():
		var syntax = script.get_base_editor().syntax_highlighter
		if syntax is EditorHL:
			syntax.reset_highlighter()
			#syntax.clear_highlighting_cache()
