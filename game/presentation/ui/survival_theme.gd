extends RefCounted

const BG: Color = Color("10191d")
const PANEL: Color = Color("1a272c")
const BORDER: Color = Color("34474d")
const TEXT: Color = Color("e4ebdf")
const MUTED: Color = Color("97aaa9")
const ACCENT: Color = Color("e3b968")
const GREEN: Color = Color("9bc3a0")
const RED: Color = Color("e39788")

static func box(color: Color, border: Color = BORDER, pad: int = 14) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = pad
	style.content_margin_right = pad
	style.content_margin_top = pad
	style.content_margin_bottom = pad
	return style

static func create() -> Theme:
	var theme: Theme = Theme.new()
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK SC","Microsoft YaHei","PingFang SC","WenQuanYi Micro Hei","DejaVu Sans"])
	theme.default_font = font
	if ResourceLoader.exists("res://game/assets_art/fonts/AftermapUI.otf"):
		theme.default_font = load("res://game/assets_art/fonts/AftermapUI.otf")
	theme.default_font_size = 17
	theme.set_color("font_color","Label",TEXT)
	theme.set_color("default_color","RichTextLabel",TEXT)
	for type in ["Button","OptionButton"]:
		theme.set_stylebox("normal",type,box(Color("223239"),BORDER,12))
		theme.set_stylebox("hover",type,box(Color("30434a"),ACCENT,12))
		theme.set_stylebox("pressed",type,box(Color("3d4d46"),ACCENT,12))
		theme.set_stylebox("disabled",type,box(Color("19252a"),Color("29383e"),12))
		theme.set_stylebox("focus",type,box(Color(0,0,0,0),ACCENT,0))
		theme.set_color("font_color",type,TEXT)
		theme.set_color("font_hover_color",type,Color.WHITE)
		theme.set_color("font_disabled_color",type,Color("657877"))
	theme.set_stylebox("panel","PanelContainer",box(PANEL))
	theme.set_stylebox("panel","PopupMenu",box(PANEL))
	theme.set_color("font_color","PopupMenu",TEXT)
	theme.set_stylebox("background","ProgressBar",box(Color("0e181b"),Color("0e181b"),0))
	theme.set_stylebox("fill","ProgressBar",box(GREEN,GREEN,0))
	theme.set_constant("separation","VBoxContainer",10)
	theme.set_constant("separation","HBoxContainer",12)
	return theme
