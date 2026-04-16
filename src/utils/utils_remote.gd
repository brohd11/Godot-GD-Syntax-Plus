#! remote

const EditorPluginManager = preload("res://addons/addon_lib/brohd/editor_plugin_manager/editor_plugin_manager.gd")
const PopupWrapper = preload("res://addons/addon_lib/brohd/popup_wrapper/popup_wrapper.gd")
const DockManager = preload("res://addons/addon_lib/brohd/dock_manager/dock_manager.gd")

const PopupHelper = preload("uid://bb13ihrvdkjdj") #! resolve PopupWrapper.PopupHelper
const UFile = preload("uid://gs632l1nhxaf") #! resolve ALibRuntime.Utils.UFile
const URegex = preload("uid://cpjnb72qn8bmh")  #! resolve ALibRuntime.Utils.URegex
const UString = preload("uid://cwootkivqiwq1") #! resolve ALibRuntime.Utils.UString

const UGDScript = preload("uid://bqwb564jwff43") #! resolve ALibRuntime.Utils.UGDScript
const UClassDetail = UGDScript.UClassDetail
const GDScriptParser = UGDScript.Parser
const SettingHelperEditor = preload("uid://c4l4v4eufkmtx") #! resolve ALibEditor.Settings.SettingHelperEditor
const ConfirmationDialogHandler = preload("uid://b4rwv7tgks0b5") #! resolve ALibRuntime.Dialog.Handlers.Confirmation

const EditorGDScriptParser = preload("uid://t2dewmuth0sy") #! resolve ALibEditor.Singletons.EditorGDScriptParser
const ScriptListManager = preload("uid://d3o6grkkmk4qk") #! resolve ALibEditor.Singletons.ScriptListManager
