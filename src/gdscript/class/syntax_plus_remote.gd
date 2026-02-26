#! remote

const EditorPluginManager = preload("res://addons/addon_lib/brohd/editor_plugin_manager/editor_plugin_manager.gd")
const PopupHelper = preload("res://addons/addon_lib/brohd/alib_runtime/popup_menu/popup_menu_path_helper.gd")
const UFile = preload("uid://gs632l1nhxaf") # u_file.gd
const URegex = preload("uid://cpjnb72qn8bmh") # u_regex.gd
const UString = preload("res://addons/addon_lib/brohd/alib_runtime/utils/u_string.gd")

const UClassDetail = preload("res://addons/addon_lib/brohd/alib_editor/utils/src/u_class_detail.gd")
const SettingHelperEditor = preload("res://addons/addon_lib/brohd/alib_editor/settings/setting_helper.gd")

const ConfirmationDialogHandler = preload("uid://bccd38qwc47vu").Handlers.Confirmation # dialog.gd

const PopupWrapper = preload("res://addons/addon_lib/brohd/popup_wrapper/popup_wrapper.gd")
const DockManager = preload("res://addons/addon_lib/brohd/dock_manager/dock_manager.gd")
