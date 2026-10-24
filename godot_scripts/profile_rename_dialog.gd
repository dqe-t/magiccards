class_name ProfileRenameDialog
extends Control

signal confirmed(new_name: String)
signal cancelled

var is_dialog_open: bool = false
var callback: Callable = Callable()

var overlay: ColorRect = null
var card_panel: Panel = null
var title_label: Label = null
var line_edit: LineEdit = null
var err_label: Label = null
var btn_ok: Button = null
var btn_cancel: Button = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func _build_ui() -> void:
	self.overlay = ColorRect.new()
	self.overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	self.overlay.color = Color(0.0, 0.0, 0.0, 0.45)
	self.overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(self.overlay)

	self.card_panel = Panel.new()
	self.card_panel.custom_minimum_size = Vector2(440.0, 210.0)
	var card_sb: StyleBoxFlat = StyleBoxFlat.new()
	card_sb.bg_color = Color.WHITE
	card_sb.set_corner_radius_all(14)
	card_sb.shadow_size = 12
	card_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	card_sb.border_width_bottom = 2
	card_sb.border_width_left = 2
	card_sb.border_width_right = 2
	card_sb.border_width_top = 2
	card_sb.border_color = Color8(180, 180, 190)
	self.card_panel.add_theme_stylebox_override("panel", card_sb)
	add_child(self.card_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	var margin_c: MarginContainer = MarginContainer.new()
	margin_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin_c.add_theme_constant_override("margin_left", 24)
	margin_c.add_theme_constant_override("margin_right", 24)
	margin_c.add_theme_constant_override("margin_top", 20)
	margin_c.add_theme_constant_override("margin_bottom", 20)
	margin_c.add_child(vbox)
	self.card_panel.add_child(margin_c)

	var is_fr: bool = ConfigManager.is_system_french()
	self.title_label = Label.new()
	self.title_label.text = "Renommer le profil" if is_fr else "Rename profile"
	self.title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	self.title_label.add_theme_font_size_override("font_size", 20)
	self.title_label.add_theme_color_override("font_color", Color8(20, 20, 25))
	vbox.add_child(self.title_label)

	self.line_edit = LineEdit.new()
	self.line_edit.placeholder_text = "Nom du profil" if is_fr else "Profile name"
	self.line_edit.max_length = 16
	self.line_edit.custom_minimum_size = Vector2(0.0, 42.0)
	self.line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	self.line_edit.add_theme_font_size_override("font_size", 18)
	self.line_edit.text_submitted.connect(_on_text_submitted)
	vbox.add_child(self.line_edit)

	self.err_label = Label.new()
	self.err_label.text = ""
	self.err_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	self.err_label.add_theme_font_size_override("font_size", 14)
	self.err_label.add_theme_color_override("font_color", Color8(215, 45, 45))
	self.err_label.visible = false
	vbox.add_child(self.err_label)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	self.btn_cancel = Button.new()
	self.btn_cancel.text = ""
	self.btn_cancel.custom_minimum_size = Vector2(72.0, 44.0)
	self.btn_cancel.icon = UIWidgets.get_icon_texture("EXIT", 26)
	self.btn_cancel.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cancel_sb: StyleBoxFlat = StyleBoxFlat.new()
	cancel_sb.bg_color = Color8(240, 240, 245)
	cancel_sb.set_corner_radius_all(10)
	cancel_sb.border_width_bottom = 1
	cancel_sb.border_width_left = 1
	cancel_sb.border_width_right = 1
	cancel_sb.border_width_top = 1
	cancel_sb.border_color = Color8(190, 190, 200)
	self.btn_cancel.add_theme_stylebox_override("normal", cancel_sb)
	self.btn_cancel.add_theme_color_override("icon_normal_color", Color8(50, 50, 60))
	self.btn_cancel.pressed.connect(_on_cancel_pressed)
	hbox.add_child(self.btn_cancel)

	self.btn_ok = Button.new()
	self.btn_ok.text = ""
	self.btn_ok.custom_minimum_size = Vector2(72.0, 44.0)
	self.btn_ok.icon = UIWidgets.get_icon_texture("CHECK", 26)
	self.btn_ok.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ok_sb: StyleBoxFlat = StyleBoxFlat.new()
	ok_sb.bg_color = Color8(20, 20, 25)
	ok_sb.set_corner_radius_all(10)
	self.btn_ok.add_theme_stylebox_override("normal", ok_sb)
	self.btn_ok.add_theme_color_override("icon_normal_color", Color.WHITE)
	self.btn_ok.pressed.connect(_on_ok_pressed)
	hbox.add_child(self.btn_ok)


func is_open() -> bool:
	return self.is_dialog_open


func open(initial_name: String, on_confirm: Callable) -> void:
	if not on_confirm.is_valid():
		FailFast.fail("CRITICAL: on_confirm must be a valid Callable.")
		return

	var is_fr: bool = ConfigManager.is_system_french()
	self.title_label.text = "Renommer le profil" if is_fr else "Rename profile"
	self.line_edit.placeholder_text = "Nom du profil" if is_fr else "Profile name"
	self.callback = on_confirm
	self.line_edit.text = initial_name
	self.err_label.text = ""
	self.err_label.visible = false
	self.is_dialog_open = true
	visible = true

	if is_inside_tree():
		var vp_sz: Vector2 = get_viewport_rect().size
		if vp_sz.x > 0 and vp_sz.y > 0:
			var card_w: float = 440.0
			var card_h: float = 210.0
			self.card_panel.position = Vector2(
				(vp_sz.x - card_w) * 0.5,
				(vp_sz.y - card_h) * 0.5
			)
		self.line_edit.grab_focus()
		self.line_edit.select_all()


func close() -> void:
	self.is_dialog_open = false
	visible = false
	if is_inside_tree() and self.line_edit.has_focus():
		self.line_edit.release_focus()


func _on_text_submitted(_text: String) -> void:
	_on_ok_pressed()


func _on_ok_pressed() -> void:
	var trimmed: String = self.line_edit.text.strip_edges()
	if trimmed.is_empty():
		var is_fr: bool = ConfigManager.is_system_french()
		self.err_label.text = "Le nom ne peut pas être vide !" if is_fr else "Name cannot be empty!"
		self.err_label.visible = true
		return

	close()
	if self.callback.is_valid():
		self.callback.call(trimmed)
	confirmed.emit(trimmed)


func _on_cancel_pressed() -> void:
	close()
	cancelled.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not self.is_dialog_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_cancel_pressed()
			get_viewport().set_input_as_handled()
