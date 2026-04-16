
const Settings = preload("res://addons/syntax_plus/src/utils/config/settings.gd")

static var data := {}

#! arg_location setting:Settings
static func get_setting(setting:StringName):
	return data.get(setting)

static func initialize():
	initial_set_editor_settings()
	load_data()
	EditorInterface.get_editor_settings().settings_changed.connect(load_data)

static func initial_set_editor_settings():
	var settings_array = [
		Settings.SET_AS_DEFAULT_HIGHLIGHTER,
		Settings.CONST_COLOR,
		Settings.CONST_ENABLE,
		Settings.PASCAL_COLOR,
		Settings.PASCAL_ENABLE,
		Settings.ONREADY_COLOR,
		Settings.ONREADY_ENABLE,
		Settings.MEMBER_COLOR,
		Settings.MEMBER_ENABLE,
		Settings.INHERITED_MEMBER_COLOR,
		Settings.INHERITED_MEMBER_ENABLE,
		Settings.INHERITED_MEMBER_RESPECT_CASE,
		Settings.BASE_TYPE_MEMBER_COLOR,
		Settings.BASE_TYPE_MEMBER_ENABLE,
		Settings.INNER_CLASS_MEMBER_COLOR,
		Settings.INNER_CLASS_MEMBER_ENABLE,
		Settings.MEMBER_ACCESS_COLOR,
		Settings.MEMBER_ACCESS_ENABLE,
		Settings.TAG_COLOR,
		Settings.TAG_COLOR_ENABLE,
	]
	var ed_settings = EditorInterface.get_editor_settings()
	for setting in settings_array:
		if ed_settings.has_setting(setting):
			continue
		var val = Settings.DEFAULT_SETTINGS.get(setting)
		ed_settings.set_setting(setting, val)


static func load_data():
	data = {}
	for key in Settings.DEFAULT_SETTINGS.keys():
		data[key] = _get_editor_setting(key)

static func _get_editor_setting(setting:String):
	var ed_s = EditorInterface.get_editor_settings()
	if ed_s.has_setting(setting):
		return ed_s.get_setting(setting)
	else:
		var default_val = Settings.DEFAULT_SETTINGS.get(setting)
		ed_s.set_setting(setting, default_val)
		return ed_s.get_setting(setting)

static func get_tags_data():
	var ed_settings = EditorInterface.get_editor_settings()
	if not ed_settings.has_setting(Settings.DEFINED_TAGS):
		ed_settings.set_setting(Settings.DEFINED_TAGS, Settings.DEFAULT_TAGS.get("tags"))
	return ed_settings.get_setting(Settings.DEFINED_TAGS)

static func unset():
	var ed_settings = EditorInterface.get_editor_settings()
	for key in Settings.DEFAULT_SETTINGS.keys():
		ed_settings.set_setting(key, null)
