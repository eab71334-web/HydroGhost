extends Control
# Pro-style HUD + multi-touch controls, all drawn in code.

signal water_pressed
signal possess_pressed

var move_vec := Vector2.ZERO
var jump_held := false
var look_delta := Vector2.ZERO
var health := 100.0
var speed := 0.0
var water_form := false
var can_possess := false

var _fingers := {}
var _joy_origin := Vector2.ZERO
var _pulse := 0.0
var _l := 0.0
var _t := 0.0
var _r := 0.0
var _b := 0.0
var _panel := StyleBoxFlat.new()
var _track := StyleBoxFlat.new()
var _fill := StyleBoxFlat.new()
var _pill := StyleBoxFlat.new()
var _font: Font

const ACCENT := Color(0.3, 0.75, 1.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_panel.bg_color = Color(0.03, 0.07, 0.13, 0.62)
	_panel.border_color = Color(1, 1, 1, 0.14)
	_panel.set_corner_radius_all(18)
	_panel.set_border_width_all(2)
	_track.bg_color = Color(1, 1, 1, 0.12)
	_track.set_corner_radius_all(11)
	_fill.set_corner_radius_all(11)
	_pill.set_corner_radius_all(20)
	_pill.set_border_width_all(2)
	_layout()

# Size the HUD to the visible screen by hand (anchors under a CanvasLayer were unreliable)
# and read the phone's safe area (notch / rounded corners).
func _layout() -> void:
	var vs := get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	_l = 0.0
	_t = 0.0
	_r = 0.0
	_b = 0.0
	if OS.has_feature("android") or OS.has_feature("ios"):
		var win := Vector2(DisplayServer.window_get_size())
		var sa := Rect2(DisplayServer.get_display_safe_area())
		if win.x > 0.0 and sa.size.x > 0.0:
			var k := vs / win
			_l = clampf(sa.position.x * k.x, 0.0, 140.0)
			_t = clampf(sa.position.y * k.y, 0.0, 140.0)
			_r = clampf(vs.x - sa.end.x * k.x, 0.0, 140.0)
			_b = clampf(vs.y - sa.end.y * k.y, 0.0, 140.0)

func _process(delta: float) -> void:
	_pulse += delta
	_layout()
	queue_redraw()

func _btn_pos(id: String) -> Vector2:
	var rx := size.x - _r
	var by := size.y - _b
	match id:
		"jump": return Vector2(rx - 150, by - 140)
		"water": return Vector2(rx - 320, by - 90)
	return Vector2(rx - 110, by - 300)

func _hit(p: Vector2) -> String:
	if p.distance_to(_btn_pos("jump")) < 85.0: return "jump"
	if p.distance_to(_btn_pos("water")) < 70.0: return "water"
	if p.distance_to(_btn_pos("possess")) < 70.0: return "possess"
	return "joy" if p.x < size.x * 0.5 else "look"

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var role := _hit(event.position)
			_fingers[event.index] = role
			match role:
				"jump": jump_held = true
				"water": water_pressed.emit()
				"possess":
					if can_possess:
						possess_pressed.emit()
				"joy": _joy_origin = event.position
		else:
			var r: String = _fingers.get(event.index, "")
			if r == "jump": jump_held = false
			if r == "joy": move_vec = Vector2.ZERO
			_fingers.erase(event.index)
	elif event is InputEventScreenDrag:
		var r: String = _fingers.get(event.index, "")
		if r == "joy":
			move_vec = ((event.position - _joy_origin) / 80.0).limit_length(1.0)
		elif r == "look":
			look_delta += event.relative

func _txt(pos: Vector2, s: String, size_px: int, col: Color, w := -1.0, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(_font, pos, s, al, w, size_px, col)

func _draw() -> void:
	var hp := clampf(health / 100.0, 0.0, 1.0)
	var dim := Color(1, 1, 1, 0.7)
	# Health (top-left)
	draw_set_transform(Vector2(_l, _t))
	draw_style_box(_panel, Rect2(24, 24, 360, 92))
	_txt(Vector2(46, 56), "HEALTH", 18, dim)
	_txt(Vector2(46, 56), str(int(health)), 22, Color.WHITE, 316.0, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_style_box(_track, Rect2(46, 70, 316, 22))
	_fill.bg_color = Color(0.95, 0.25, 0.25).lerp(Color(0.3, 0.9, 0.5), hp)
	if hp > 0.03:
		draw_style_box(_fill, Rect2(46, 70, 316.0 * hp, 22))
	# Speed (top-right)
	draw_set_transform(Vector2(size.x - _r - 254.0, _t))
	draw_style_box(_panel, Rect2(0, 24, 230, 92))
	_txt(Vector2(22, 54), "SPEED", 18, dim)
	_txt(Vector2(22, 100), str(int(speed)), 44, Color.WHITE)
	_txt(Vector2(88, 100), "km/h", 18, dim)
	var gc := Vector2(185, 72)
	draw_arc(gc, 26, PI * 0.75, PI * 2.25, 32, Color(1, 1, 1, 0.15), 6.0, true)
	var sr := clampf(speed / 36.0, 0.0, 1.0)
	if sr > 0.02:
		draw_arc(gc, 26, PI * 0.75, PI * 0.75 + PI * 1.5 * sr, 32, ACCENT, 6.0, true)
	# Form pill (top-center)
	draw_set_transform(Vector2(0, _t))
	var pc := ACCENT if water_form else Color(1.0, 0.8, 0.4)
	_pill.bg_color = Color(pc, 0.22)
	_pill.border_color = Color(pc, 0.8)
	draw_style_box(_pill, Rect2(size.x * 0.5 - 90, 30, 180, 40))
	_txt(Vector2(size.x * 0.5 - 90, 58), "WATER FORM" if water_form else "HUMAN", 20, Color.WHITE, 180.0, HORIZONTAL_ALIGNMENT_CENTER)
	if can_possess:
		var a := 0.6 + 0.4 * sin(_pulse * 6.0)
		_txt(Vector2(0, 104), "Tap POSSESS to enter the person", 20, Color(1, 1, 1, a), size.x, HORIZONTAL_ALIGNMENT_CENTER)
	draw_set_transform(Vector2.ZERO)
	# Joystick
	var active := false
	for v in _fingers.values():
		if v == "joy":
			active = true
	var base := _joy_origin if active else Vector2(_l + 190.0, size.y - _b - 160.0)
	draw_circle(base, 90, Color(1, 1, 1, 0.08))
	draw_arc(base, 90, 0, TAU, 48, Color(1, 1, 1, 0.3 if active else 0.15), 3.0, true)
	draw_circle(base + move_vec * 70.0, 38, Color(1, 1, 1, 0.35 if active else 0.15))
	# Buttons
	_btn("jump", "JUMP", Color(1.0, 0.8, 0.4), jump_held, 85.0)
	_btn("water", "WATER", ACCENT, water_form, 70.0)
	_btn("possess", "POSSESS", Color(0.7, 0.45, 1.0) if can_possess else Color(0.6, 0.6, 0.6), can_possess, 70.0)

func _btn(id: String, label: String, col: Color, on: bool, r: float) -> void:
	var c := _btn_pos(id)
	draw_circle(c, r, Color(col, 0.32 if on else 0.14))
	draw_arc(c, r - 2.0, 0, TAU, 48, Color(col, 0.9 if on else 0.45), 4.0, true)
	_txt(c + Vector2(-r, 8), label, 20, Color.WHITE, r * 2.0, HORIZONTAL_ALIGNMENT_CENTER)
