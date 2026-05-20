
const SET_AS_DEFAULT_HIGHLIGHTER = &"plugin/syntax_plus/set_as_default_highlighter"
const PASCAL_ENABLE = &"plugin/syntax_plus/pascal/pascal_enable"
const PASCAL_COLOR = &"plugin/syntax_plus/pascal/pascal_color"
const CONST_ENABLE = &"plugin/syntax_plus/constant/constant_enable"
const CONST_COLOR = &"plugin/syntax_plus/constant/constant_color"
const MEMBER_ENABLE = &"plugin/syntax_plus/member/member_enable"
const MEMBER_COLOR = &"plugin/syntax_plus/member/member_color"
const INHERITED_MEMBER_ENABLE = &"plugin/syntax_plus/inherited/inherited_member_enable"
const INHERITED_MEMBER_COLOR = &"plugin/syntax_plus/inherited/inherited_member_color"
const INHERITED_MEMBER_RESPECT_CASE = &"plugin/syntax_plus/inherited/inherited_member_respect_case"
const BASE_TYPE_MEMBER_ENABLE = &"plugin/syntax_plus/inherited/base_type_member_enable"
const BASE_TYPE_MEMBER_COLOR = &"plugin/syntax_plus/inherited/base_type_member_color"
const INNER_CLASS_MEMBER_ENABLE = &"plugin/syntax_plus/inner_class/inner_class_member_enable"
const INNER_CLASS_MEMBER_COLOR = &"plugin/syntax_plus/inner_class/inner_class_member_color"
const INNER_CLASS_MEMBER_COLOR_SHIFT = &"plugin/syntax_plus/inner_class/inner_class_member_color_shift"
const MEMBER_ACCESS_ENABLE = &"plugin/syntax_plus/member_access/member_access_enable"
const MEMBER_ACCESS_COLOR = &"plugin/syntax_plus/member_access/member_access_color"
const ARGUMENT_ENABLE = &"plugin/syntax_plus/function/argument_enable"
const ARGUMENT_COLOR = &"plugin/syntax_plus/function/argument_color"
const TAG_ENABLE = &"plugin/syntax_plus/tags/tag_enable"
const TAG_COLOR = &"plugin/syntax_plus/tags/tag_color"
const TAG_COLOR_ENABLE = &"plugin/syntax_plus/tags/tag_color_enable"
const DEFINED_TAGS = &"plugin/syntax_plus/tags/defined_tags"


const DEFAULT_SETTINGS = {
	SET_AS_DEFAULT_HIGHLIGHTER: false,
	PASCAL_ENABLE: true,
	PASCAL_COLOR: Color(0.1569, 0.8784, 0.7922, 1.0),
	CONST_ENABLE: true,
	CONST_COLOR: Color(0.149, 0.5216, 0.6706, 1.0),
	MEMBER_ENABLE: true,
	MEMBER_COLOR: Color(0.7373, 0.8784, 1.0, 1.0),
	INHERITED_MEMBER_ENABLE: true,
	INHERITED_MEMBER_COLOR: Color(0.7373, 0.8784, 1.0, 1.0),
	INHERITED_MEMBER_RESPECT_CASE: false,
	BASE_TYPE_MEMBER_ENABLE: true,
	BASE_TYPE_MEMBER_COLOR: Color(0.7373, 0.8784, 1.0, 1.0),
	INNER_CLASS_MEMBER_ENABLE: false,
	INNER_CLASS_MEMBER_COLOR: Color(0.647, 0.907, 0.981, 1.0),
	INNER_CLASS_MEMBER_COLOR_SHIFT: true,
	MEMBER_ACCESS_ENABLE: false,
	MEMBER_ACCESS_COLOR: Color(0.5686, 0.7216, 0.7686, 1.0),
	ARGUMENT_ENABLE: true,
	ARGUMENT_COLOR: Color(0.733, 0.47, 0.279, 1.0),
	TAG_ENABLE: false,
	TAG_COLOR: Color(0.3725, 0.6157, 0.6235, 1.0),
	TAG_COLOR_ENABLE: true
}

const DEFAULT_TAGS = {
"tags": {
	"debug": {
		"color": Color(0.9686, 1.0, 0.0, 1.0),
		"keyword": "any",
		"menu": "Submenu",
		"overwrite": true
		}
	}
}
