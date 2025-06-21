@tool
extends VBoxContainer

const GDSynTags = preload("uid://vfj0wuk56rq7") #import gdscript_tags_code.gd

@onready var code_edit: CodeEdit = %CodeEdit

@onready var tag_line: LineEdit = %TagLine
@onready var key_line: LineEdit = %KeyLine
@onready var color_picker_button: ColorPickerButton = %ColorPickerButton
@onready var reload_button: Button = %ReloadButton
@onready var delete_button: Button = %DeleteButton
@onready var overwrite_button: Button = %OverwriteButton
@onready var menu_option: OptionButton = %MenuOption

var debounce:Timer


func _ready() -> void:
	color_picker_button.color_changed.connect(_on_color_picked)
	reload_button.pressed.connect(_on_reload_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	tag_line.text_changed.connect(_on_tag_changed)
	key_line.text_changed.connect(_on_key_changed)
	overwrite_button.pressed.connect(_on_overwrite_pressed)
	
	debounce = Timer.new()
	add_child(debounce)
	debounce.wait_time = 0.4
	debounce.one_shot = true
	debounce.timeout.connect(_on_debounce_timeout)

func set_data(tag, data):
	tag_line.text = tag
	var keywords = data.get("keyword", "")
	key_line.text = keywords
	overwrite_button.button_pressed = data.get("overwrite", false)
	var color = data.get("color")
	var color_obj = Color.html(color)
	color_picker_button.color = color_obj
	var _menu_option = data.get("menu", "submenu")
	if _menu_option == "Main Menu":
		menu_option.select(1)
	elif _menu_option == "None":
		menu_option.select(2)
	_set_tags(tag)
	set_highlighter()

func _set_tags(new_tag):
	for line in range(code_edit.get_line_count()):
		var text = code_edit.get_line(line)
		if text.strip_edges() == "":
			continue
		var comment_index = text.find("#")
		if comment_index == -1:
			continue
		var text_length = text.length()
		text = text.erase(comment_index + 1, text_length - comment_index + 1)
		text = text + new_tag
		code_edit.set_line(line, text)

func get_data():
	var tag = tag_line.text
	var keys = key_line.text
	var color = color_picker_button.color
	var overwrite = overwrite_button.button_pressed
	var menu_option = menu_option.get_item_text(menu_option.selected)
	var data = {
		tag:{
			"keyword":keys, 
			"color": color.to_html(false),
			"overwrite": overwrite,
			"menu":menu_option
			}
	}
	return data

func set_highlighter():
	var data = get_data()
	var new_hl = GDSynTags.new(data)
	code_edit.syntax_highlighter = new_hl

func _on_key_changed(new_text:String):
	
	debounce.start()

func _on_tag_changed(new_text:String):
	_set_tags(new_text)
	debounce.start()

func _on_color_picked(color:Color) -> void:
	debounce.start()

func _on_debounce_timeout():
	set_highlighter()

func _on_overwrite_pressed():
	set_highlighter()

func _on_reload_pressed():
	set_highlighter()

func _on_delete_pressed():
	queue_free()
	
