extends Node3D

const Actor = preload("res://scripts/actor.gd")
const Hud = preload("res://scripts/hud.gd")

var player: Actor
var actors: Array[Actor] = []
var cam: Camera3D
var hud: Hud
var yaw := 0.0
var pitch := 0.5
var sfx_step: AudioStreamPlayer
var sfx_wet: AudioStreamPlayer
var sfx_splash: AudioStreamPlayer
var sfx_whoosh: AudioStreamPlayer

func _ready() -> void:
	randomize()
	_environment()
	_world()
	_trees()
	_audio()
	player = _spawn(Vector3(0, 1, 10), true)
	for i in 6:
		_spawn(Vector3(randf_range(-30, 30), 1, randf_range(2, 30)), false)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	hud.water_pressed.connect(_toggle_water)
	hud.possess_pressed.connect(_possess)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 160.0
	add_child(cam)
	cam.global_position = player.global_position + Vector3(0, 5, 8)
	cam.current = true

func _spawn(pos: Vector3, ctrl: bool) -> Actor:
	var a := Actor.new()
	a.position = pos
	a.controlled = ctrl
	add_child(a)
	a.stepped.connect(_on_step)
	a.splashed.connect(_on_splash)
	actors.append(a)
	return a

# ---------------- world ----------------
func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m

func _slab(pos: Vector3, size: Vector3, c: Color, solid := true) -> void:
	var holder: Node3D = StaticBody3D.new() if solid else Node3D.new()
	holder.position = pos
	add_child(holder)
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = _mat(c)
	holder.add_child(mi)
	if solid:
		var sh := BoxShape3D.new()
		sh.size = size
		var cs := CollisionShape3D.new()
		cs.shape = sh
		holder.add_child(cs)

func _world() -> void:
	var grass := Color(0.36, 0.62, 0.28)
	var tile := Color(0.62, 0.78, 0.88)
	_slab(Vector3(-103.5, -1, 0), Vector3(193, 2, 400), grass)
	_slab(Vector3(103.5, -1, 0), Vector3(193, 2, 400), grass)
	_slab(Vector3(0, -1, 92.5), Vector3(14, 2, 195), grass)
	_slab(Vector3(0, -1, -109.5), Vector3(14, 2, 181), grass)
	_slab(Vector3(0, -2.1, -12), Vector3(14, 1, 14), tile)
	# entry ramp (rises toward +Z)
	var ramp := StaticBody3D.new()
	ramp.position = Vector3(0, -1.0, -8.6)
	ramp.rotation.x = -asin(1.6 / 7.4)
	add_child(ramp)
	var rb := BoxMesh.new()
	rb.size = Vector3(6, 0.4, 7.4)
	var rm := MeshInstance3D.new()
	rm.mesh = rb
	rm.material_override = _mat(tile)
	ramp.add_child(rm)
	var rs := BoxShape3D.new()
	rs.size = rb.size
	var rc := CollisionShape3D.new()
	rc.shape = rs
	ramp.add_child(rc)
	# pool lining + stone rim (visual only)
	_slab(Vector3(-6.95, -1, -12), Vector3(0.1, 2, 14), tile, false)
	_slab(Vector3(6.95, -1, -12), Vector3(0.1, 2, 14), tile, false)
	_slab(Vector3(0, -1, -18.95), Vector3(14, 2, 0.1), tile, false)
	_slab(Vector3(-5, -1, -5.05), Vector3(4, 2, 0.1), tile, false)
	_slab(Vector3(5, -1, -5.05), Vector3(4, 2, 0.1), tile, false)
	var stone := Color(0.82, 0.82, 0.86)
	_slab(Vector3(-7.25, 0.06, -12), Vector3(0.5, 0.12, 14.6), stone, false)
	_slab(Vector3(7.25, 0.06, -12), Vector3(0.5, 0.12, 14.6), stone, false)
	_slab(Vector3(0, 0.06, -19.25), Vector3(14.6, 0.12, 0.5), stone, false)
	# water surface
	var pm := PlaneMesh.new()
	pm.size = Vector2(14, 14)
	pm.subdivide_width = 20
	pm.subdivide_depth = 20
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/water.gdshader")
	var w := MeshInstance3D.new()
	w.mesh = pm
	w.material_override = sm
	w.position = Vector3(0, Actor.WATER_Y, -12)
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(w)

func _trees() -> void:
	var n := 40
	var tm := BoxMesh.new()
	tm.size = Vector3(0.5, 2.2, 0.5)
	var lm := BoxMesh.new()
	lm.size = Vector3(2.4, 2.0, 2.4)
	var mt := MultiMesh.new()
	mt.transform_format = MultiMesh.TRANSFORM_3D
	mt.mesh = tm
	mt.instance_count = n
	var ml := MultiMesh.new()
	ml.transform_format = MultiMesh.TRANSFORM_3D
	ml.mesh = lm
	ml.instance_count = n
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var pos := Vector3.ZERO
		for tries in 30:
			pos = Vector3(rng.randf_range(-37, 37), 0, rng.randf_range(-37, 37))
			var in_pool := absf(pos.x) < 11.0 and pos.z > -24.0 and pos.z < -2.0
			if not in_pool and pos.distance_to(Vector3(0, 0, 10)) > 6.0:
				break
		var s := rng.randf_range(0.8, 1.5)
		var b := Basis.IDENTITY.scaled(Vector3.ONE * s)
		mt.set_instance_transform(i, Transform3D(b, pos + Vector3(0, 1.1 * s, 0)))
		ml.set_instance_transform(i, Transform3D(b, pos + Vector3(0, 2.9 * s, 0)))
	var a := MultiMeshInstance3D.new()
	a.multimesh = mt
	a.material_override = _mat(Color(0.4, 0.27, 0.15))
	add_child(a)
	var c := MultiMeshInstance3D.new()
	c.multimesh = ml
	c.material_override = _mat(Color(0.2, 0.55, 0.25))
	add_child(c)

func _environment() -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.25, 0.5, 0.9)
	sky.sky_horizon_color = Color(0.72, 0.86, 1.0)
	sky.ground_horizon_color = Color(0.72, 0.86, 1.0)
	sky.ground_bottom_color = Color(0.6, 0.78, 0.95)
	var s := Sky.new()
	s.sky_material = sky
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = s
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color(0.74, 0.87, 1.0)
	e.fog_density = 0.008
	var we := WorldEnvironment.new()
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)

# ---------------- audio (procedural, no asset files) ----------------
func _noise(dur: float, decay: float, lp: float, loop := false) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var prev := 0.0
	var gain := 0.5 / (sqrt(lp / (2.0 - lp)) * 0.577)
	for i in n:
		var u := float(i) / n
		prev += (randf() * 2.0 - 1.0 - prev) * lp
		var v := prev * gain
		if not loop:
			v *= pow(1.0 - u, decay)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w

func _sfx(stream: AudioStream, vol: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = vol
	add_child(p)
	return p

func _audio() -> void:
	sfx_step = _sfx(_noise(0.09, 3.0, 0.3), -8.0)
	sfx_wet = _sfx(_noise(0.22, 1.8, 0.55), -6.0)
	sfx_splash = _sfx(_noise(0.8, 1.5, 0.7), -2.0)
	sfx_whoosh = _sfx(_noise(0.5, 1.0, 0.12), -4.0)
	var amb := AudioStreamPlayer3D.new()
	amb.stream = _noise(3.0, 0.0, 0.06, true)
	amb.position = Actor.POOL_C
	amb.volume_db = -14.0
	amb.unit_size = 8.0
	amb.max_distance = 45.0
	add_child(amb)
	amb.play()

func _play(p: AudioStreamPlayer, lo: float, hi: float) -> void:
	p.pitch_scale = randf_range(lo, hi)
	p.play()

func _on_step(actor, wet: bool) -> void:
	if actor == player:
		_play(sfx_wet if wet else sfx_step, 0.85, 1.15)

func _on_splash(actor, strong: bool) -> void:
	if actor == player:
		sfx_splash.volume_db = -2.0 if strong else -9.0
		_play(sfx_splash, 0.9, 1.1)

# ---------------- gameplay ----------------
func _toggle_water() -> void:
	if player.water_form:
		player.set_water(false)
	elif player.health > 15.0:
		player.set_water(true)
		_play(sfx_whoosh, 1.0, 1.2)

func _nearest() -> Actor:
	var best: Actor = null
	var bd := 3.5
	for a in actors:
		if a == player:
			continue
		var d := a.global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = a
	return best

func _possess() -> void:
	if not player.water_form:
		return
	var n := _nearest()
	if n == null:
		return
	var old := player
	old.controlled = false
	old.move_input = Vector2.ZERO
	old.want_jump = false
	old.set_water(false)
	n.controlled = true
	n.health = 100.0
	player = n
	n.splash_at(n.global_position.y + 0.9, false)
	_play(sfx_whoosh, 0.8, 1.0)

func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_E:
			_toggle_water()
		elif e.keycode == KEY_F:
			_possess()

func _process(delta: float) -> void:
	var kb := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	player.move_input = hud.move_vec if hud.move_vec.length() > 0.05 else kb
	player.want_jump = hud.jump_held or Input.is_physical_key_pressed(KEY_SPACE)
	yaw -= hud.look_delta.x * 0.006
	pitch = clampf(pitch + hud.look_delta.y * 0.004, 0.2, 1.1)
	hud.look_delta = Vector2.ZERO
	player.cam_yaw = yaw
	var dist := 8.5 if player.water_form else 7.0
	var tp := player.global_position + Vector3(0, 1.3, 0)
	var off := Vector3(0, 0, 1).rotated(Vector3.RIGHT, -pitch).rotated(Vector3.UP, yaw) * dist
	cam.global_position = cam.global_position.lerp(tp + off, 1.0 - exp(-9.0 * delta))
	cam.look_at(tp + Vector3(0, 0.2, 0))
	hud.health = player.health
	hud.speed = Vector2(player.velocity.x, player.velocity.z).length() * 3.6
	hud.water_form = player.water_form
	hud.can_possess = player.water_form and _nearest() != null
