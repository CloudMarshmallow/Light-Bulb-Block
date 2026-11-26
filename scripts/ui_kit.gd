class_name UIKit
extends RefCounted
## 界面工具：像素图标加载、按钮/面板样式、图标+数字状态条。

const COL_TEXT: Color = Color("f3f7ee")
const COL_DIM: Color = Color("a9b8a3")
const COL_ACCENT: Color = Color("ffd166")
const COL_PANEL: Color = Color("0e1a12cc")
const COL_PANEL_BORDER: Color = Color("3f5a3a")


static func icon(name: String) -> Texture2D:
	var path: String = "res://art/icons/" + name + ".png"
	return load(path) as Texture2D


static func make_sb(fill: Color, border: Color, radius: int = 10, width: int = 2) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	return sb


static func panel_sb() -> StyleBoxFlat:
	var sb: StyleBoxFlat = make_sb(COL_PANEL, COL_PANEL_BORDER, 16, 2)
	sb.set_content_margin_all(18)
	return sb


static func apply_btn_styles(b: Button, normal: StyleBoxFlat, hover: StyleBoxFlat) -> void:
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("disabled", make_sb(Color(0, 0, 0, 0.25), Color(0, 0, 0, 0)))


static func icon_button(name: String, px: int = 56) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(px, px)
	b.focus_mode = Control.FOCUS_NONE
	b.icon = icon(name)
	b.expand_icon = true
	b.add_theme_color_override("icon_normal_color", Color(0.90, 0.95, 0.88))
	b.add_theme_color_override("icon_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("icon_pressed_color", Color(0.78, 0.84, 0.78))
	b.add_theme_color_override("icon_disabled_color", Color(0.32, 0.38, 0.32, 0.9))
	apply_btn_styles(b, make_sb(Color(0.05, 0.10, 0.06, 0.72), Color(0.25, 0.36, 0.24), 12, 2),
		make_sb(Color(0.12, 0.20, 0.13, 0.92), Color(0.55, 0.72, 0.45), 12, 2))
	return b


static func menu_button(icon_name: String, text: String, w: int = 340, h: int = 78) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.icon = icon(icon_name)
	b.expand_icon = false
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("icon_normal_color", COL_ACCENT)
	b.add_theme_color_override("icon_hover_color", Color(1, 1, 1))
	b.add_theme_constant_override("icon_max_width", 44)
	b.add_theme_constant_override("h_separation", 14)
	apply_btn_styles(b, make_sb(Color(0.04, 0.09, 0.05, 0.80), Color(0.28, 0.40, 0.26), 14, 2),
		make_sb(Color(0.13, 0.22, 0.14, 0.95), Color(0.62, 0.80, 0.50), 14, 2))
	return b


static func menu_icon_button(icon_name: String, tooltip: String, px: int = 108) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(px, px)
	b.icon = icon(icon_name)
	b.expand_icon = true
	b.tooltip_text = tooltip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("icon_normal_color", Color(0.96, 0.98, 0.90))
	b.add_theme_color_override("icon_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("icon_pressed_color", Color(0.82, 0.88, 0.78))
	apply_btn_styles(b, make_sb(Color(0.04, 0.09, 0.05, 0.82), Color(0.30, 0.43, 0.27), 18, 2),
		make_sb(Color(0.13, 0.22, 0.14, 0.95), Color(0.66, 0.84, 0.52), 18, 2))
	return b


static func stat(icon_name: String, value: String = "0", icon_px: int = 30, font_size: int = 26) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var tex: TextureRect = TextureRect.new()
	tex.texture = icon(icon_name)
	tex.custom_minimum_size = Vector2(icon_px, icon_px)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.modulate = Color(0.92, 0.96, 0.88)
	row.add_child(tex)
	var label: Label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COL_TEXT)
	row.add_child(label)
	return row


static func stat_label(row: HBoxContainer) -> Label:
	return row.get_child(1) as Label


static func title_label(text: String, font_size: int = 64) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var settings: LabelSettings = LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = Color("fff6dd")
	settings.outline_size = 10
	settings.outline_color = Color(0.05, 0.12, 0.06, 0.95)
	label.label_settings = settings
	return label


static func dim_layer(alpha: float = 0.45) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.color = Color(0, 0, 0, alpha)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	return rect


static func overlay_panel(min_size: Vector2 = Vector2(560, 0)) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_sb())
	panel.custom_minimum_size = min_size
	return panel
