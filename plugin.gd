@tool
extends EditorPlugin

const UtilsRemote = preload("res://addons/syntax_plus/src/utils/utils_remote.gd")
const EditorGDScriptParser = UtilsRemote.EditorGDScriptParser

const PLUGIN_NAME = "SyntaxPlus"

func _get_plugin_name() -> String:
	return PLUGIN_NAME
func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("SyntaxHighlighter", &"EditorIcons")

func _enter_tree() -> void:
	SyntaxPlusSingleton.register_node(self)
	EditorGDScriptParser.register_node(self)


func _exit_tree() -> void:
	SyntaxPlusSingleton.unregister_node(self)
	EditorGDScriptParser.unregister_node(self)
