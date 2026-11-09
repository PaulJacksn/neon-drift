extends CanvasLayer
## All UI: menu, HUD, pause, game over. No text-heavy instructions.

signal pause_pressed
signal resume_pressed
signal restart_pressed

var _score_label: Label
var _combo_label: Label
var _best_label: Label
var _speed_fill: ColorRect
var _menu: Control
var _menu_best: Label
var _tap_label: Label
var _gameover: Control
var _go_score: Label
var _go_best: Label
var _new_best: Label
var _pause_panel: Control
var _popup: Label
var _popup_time := 0.0
var _flash: ColorRect
var _time := 0.0

func _ready() -> void:
	_build_vignette()
	_build_hud()
	_build_menu()
	_build_gameover()
	_build_pause()
	_build_popup()
	_build_flash()

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.06))
	l.add_theme_constant_override("outline_size", max(4, size / 8))
	return l

func _build_vignette() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.55))
	grad.set_offset(0, 0.55)
	grad.set_offset(1, 1.0)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 512
	tex.height = 512
	var rect := TextureRect.new()
	rect.texture = tex
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(rect)

func _build_hud() -> void:
	_score_label = _label("0", 72, Color(0.5, 0.95, 1.0))
	_score_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_score_label.position = Vector2(-200, 28)
	_score_label.size = Vector2(400, 90)
	add_child(_score_label)
	_combo_label = _label("", 30, Color(1.0, 0.45, 0.9))
	_combo_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_combo_label.position = Vector2(-200, 118)
	_combo_label.size = Vector2(400, 40)
	add_child(_combo_label)
	_best_label = _label("", 24, Color(0.7, 0.75, 0.9))
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_best_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_best_label.position = Vector2(20, 20)
	_best_label.size = Vector2(300, 34)
	add_child(_best_label)
	# Pause button, top right
	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.position = Vector2(-76, 16)
	pause_btn.size = Vector2(56, 56)
	pause_btn.add_theme_font_size_override("font_size", 26)
	pause_btn.add_theme_stylebox_override("normal", _btn_style(Color(0.05, 0.08, 0.2, 0.7)))
	pause_btn.add_theme_stylebox_override("hover", _btn_style(Color(0.1, 0.15, 0.35, 0.8)))
	pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	add_child(pause_btn)
	# Speed bar, bottom center
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(1, 1, 1, 0.12)
	bar_bg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar_bg.position = Vector2(-120, -56)
	bar_bg.size = Vector2(240, 10)
	add_child(bar_bg)
	_speed_fill = ColorRect.new()
	_speed_fill.color = Color(0.0, 0.94, 1.0)
	_speed_fill.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speed_fill.position = Vector2(-120, -56)
	_speed_fill.size = Vector2(0, 10)
	add_child(_speed_fill)
	var speed_label := _label("SPEED", 18, Color(0.6, 0.7, 0.85))
	speed_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	speed_label.position = Vector2(-120, -84)
	speed_label.size = Vector2(240, 24)
	add_child(speed_label)

func _btn_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = 12
	s.corner_radius_top_right = 12
	s.corner_radius_bottom_left = 12
	s.corner_radius_bottom_right = 12
	return s

func _build_menu() -> void:
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu)
	var title_neon := _label("NEON", 110, Color(0.0, 0.94, 1.0))
	title_neon.set_anchors_preset(Control.PRESET_CENTER)
	title_neon.position = Vector2(-300, -260)
	title_neon.size = Vector2(600, 130)
	_menu.add_child(title_neon)
	var title_drift := _label("DRIFT", 110, Color(1.0, 0.17, 0.84))
	title_drift.set_anchors_preset(Control.PRESET_CENTER)
	title_drift.position = Vector2(-300, -140)
	title_drift.size = Vector2(600, 130)
	_menu.add_child(title_drift)
	var sub := _label("DRAG TO FLY  •  DODGE  •  THREAD THE RINGS", 24, Color(0.85, 0.9, 1.0))
	sub.set_anchors_preset(Control.PRESET_CENTER)
	sub.position = Vector2(-300, 10)
	sub.size = Vector2(600, 34)
	_menu.add_child(sub)
	_menu_best = _label("", 26, Color(1.0, 0.84, 0.37))
	_menu_best.set_anchors_preset(Control.PRESET_CENTER)
	_menu_best.position = Vector2(-300, 60)
	_menu_best.size = Vector2(600, 36)
	_menu.add_child(_menu_best)
	_tap_label = _label("TAP TO START", 36, Color(1, 1, 1))
	_tap_label.set_anchors_preset(Control.PRESET_CENTER)
	_tap_label.position = Vector2(-300, 170)
	_tap_label.size = Vector2(600, 50)
	_menu.add_child(_tap_label)

func _build_gameover() -> void:
	_gameover = Control.new()
	_gameover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gameover.visible = false
	add_child(_gameover)
	var title := _label("RUN OVER", 84, Color(1.0, 0.3, 0.45))
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-300, -240)
	title.size = Vector2(600, 110)
	_gameover.add_child(title)
	_new_best = _label("NEW BEST!", 34, Color(1.0, 0.84, 0.37))
	_new_best.set_anchors_preset(Control.PRESET_CENTER)
	_new_best.position = Vector2(-300, -130)
	_new_best.size = Vector2(600, 46)
	_gameover.add_child(_new_best)
	_go_score = _label("0", 96, Color(0.5, 0.95, 1.0))
	_go_score.set_anchors_preset(Control.PRESET_CENTER)
	_go_score.position = Vector2(-300, -80)
	_go_score.size = Vector2(600, 120)
	_gameover.add_child(_go_score)
	_go_best = _label("", 28, Color(0.8, 0.85, 0.95))
	_go_best.set_anchors_preset(Control.PRESET_CENTER)
	_go_best.position = Vector2(-300, 50)
	_go_best.size = Vector2(600, 38)
	_gameover.add_child(_go_best)
	var tap := _label("TAP TO FLY AGAIN", 34, Color(1, 1, 1))
	tap.set_anchors_preset(Control.PRESET_CENTER)
	tap.position = Vector2(-300, 170)
	tap.size = Vector2(600, 50)
	_gameover.add_child(tap)

func _build_pause() -> void:
	_pause_panel = Control.new()
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.visible = false
	add_child(_pause_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.05, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.add_child(dim)
	var title := _label("PAUSED", 72, Color(0.5, 0.95, 1.0))
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-300, -160)
	title.size = Vector2(600, 90)
	_pause_panel.add_child(title)
	var resume_btn := Button.new()
	resume_btn.text = "RESUME"
	resume_btn.set_anchors_preset(Control.PRESET_CENTER)
	resume_btn.position = Vector2(-130, -30)
	resume_btn.size = Vector2(260, 70)
	resume_btn.add_theme_font_size_override("font_size", 32)
	resume_btn.add_theme_stylebox_override("normal", _btn_style(Color(0.0, 0.5, 0.6)))
	resume_btn.add_theme_stylebox_override("hover", _btn_style(Color(0.0, 0.65, 0.75)))
	resume_btn.pressed.connect(func() -> void: resume_pressed.emit())
	_pause_panel.add_child(resume_btn)
	var restart_btn := Button.new()
	restart_btn.text = "RESTART"
	restart_btn.set_anchors_preset(Control.PRESET_CENTER)
	restart_btn.position = Vector2(-130, 60)
	restart_btn.size = Vector2(260, 70)
	restart_btn.add_theme_font_size_override("font_size", 32)
	restart_btn.add_theme_stylebox_override("normal", _btn_style(Color(0.5, 0.1, 0.45)))
	restart_btn.add_theme_stylebox_override("hover", _btn_style(Color(0.65, 0.15, 0.55)))
	restart_btn.pressed.connect(func() -> void: restart_pressed.emit())
	_pause_panel.add_child(restart_btn)

func _build_popup() -> void:
	_popup = _label("", 40, Color(1.0, 0.84, 0.37))
	_popup.set_anchors_preset(Control.PRESET_CENTER)
	_popup.position = Vector2(-300, -40)
	_popup.size = Vector2(600, 56)
	_popup.modulate.a = 0.0
	add_child(_popup)

func _build_flash() -> void:
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

func _process(delta: float) -> void:
	_time += delta
	# Pulsing tap-to-start
	var pulse := 0.55 + 0.45 * sin(_time * 4.0)
	_tap_label.modulate.a = pulse
	# Popup fade
	if _popup_time > 0.0:
		_popup_time -= delta
		_popup.modulate.a = clampf(_popup_time / 0.9, 0.0, 1.0)
	# Flash decay
	if _flash.color.a > 0.0:
		var c := _flash.color
		c.a = maxf(0.0, c.a - delta * 2.5)
		_flash.color = c

# ---------------------------------------------------------------- public API

func set_score(value: int) -> void:
	_score_label.text = str(value)

func set_combo(combo: int, mult: int) -> void:
	if combo >= 2:
		_combo_label.text = "COMBO x%d" % mult
	else:
		_combo_label.text = ""

func set_best(value: int) -> void:
	_best_label.text = "BEST  %d" % value
	_menu_best.text = "BEST  %d" % value if value > 0 else ""

func set_speed_ratio(ratio: float) -> void:
	_speed_fill.size.x = 240.0 * clampf(ratio, 0.0, 1.0)

func show_popup(text: String) -> void:
	_popup.text = text
	_popup.modulate.a = 1.0
	_popup_time = 0.9

func flash() -> void:
	var c := _flash.color
	c.a = 0.55
	_flash.color = c

func show_menu() -> void:
	_menu.visible = true
	_gameover.visible = false
	_pause_panel.visible = false
	_score_label.visible = false
	_combo_label.visible = false

func show_hud() -> void:
	_menu.visible = false
	_gameover.visible = false
	_pause_panel.visible = false
	_score_label.visible = true
	_combo_label.visible = true

func show_gameover(score: int, best: int, is_new_best: bool) -> void:
	_gameover.visible = true
	_go_score.text = str(score)
	_go_best.text = "BEST  %d" % best
	_new_best.visible = is_new_best
	_score_label.visible = false
	_combo_label.visible = false

func show_pause() -> void:
	_pause_panel.visible = true

func hide_pause() -> void:
	_pause_panel.visible = false
