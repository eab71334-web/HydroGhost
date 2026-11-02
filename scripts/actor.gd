extends CharacterBody3D
# Blocky human that can melt into a water blob. Controlled by the player or by simple AI.

signal stepped(actor, wet)
signal splashed(actor, strong)

const POOL_C := Vector3(0, 0, -12)
const POOL_H := 7.0
const WATER_Y := -0.35
const LOD_DIST := 24.0
const GRAV := 24.0

static var _meshes := {}
static var _mats := {}
static var _water: StandardMaterial3D

var controlled := false
var water_form := false
var health := 100.0
var move_input := Vector2.ZERO
var want_jump := false
var cam_yaw := 0.0
var in_water := false
var morph := 0.0
var phase := 0.0
var squash := 0.0
var step_acc := 0.0
var was_floor := true
var t := 0.0
var yaw := 0.0
var ai_dir := Vector3.ZERO
var ai_t := 0.0
var rig: Node3D
var torso: Node3D
var head: Node3D
var blob: Node3D
var col: CollisionShape3D
var cap: CapsuleShape3D
var drips: CPUParticles3D
var splash: CPUParticles3D
var legs: Array[Node3D] = []
var knees: Array[Node3D] = []
var arms: Array[Node3D] = []
var elbows: Array[Node3D] = []

static func water_mat() -> StandardMaterial3D:
	if _water == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.25, 0.6, 1.0, 0.62)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.emission_enabled = true
		m.emission = Color(0.05, 0.25, 0.55)
		m.rim_enabled = true
		m.rim = 0.8
		_water = m
	return _water

static func _mat(c: Color) -> StandardMaterial3D:
	if not _mats.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		_mats[c] = m
	return _mats[c]

# Shared meshes/materials = few draw calls. near=true parts vanish beyond LOD_DIST (replaced by far boxes).
func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, near := true) -> void:
	if not _meshes.has(size):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[size] = bm
	var m := MeshInstance3D.new()
	m.mesh = _meshes[size]
	m.material_override = _mat(c)
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if size.y > 0.35 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if near:
		m.visibility_range_end = LOD_DIST
	else:
		m.visibility_range_begin = LOD_DIST
	parent.add_child(m)

func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func _ready() -> void:
	t = randf() * 10.0
	cap = CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	col = CollisionShape3D.new()
	col.shape = cap
	col.position.y = 0.9
	add_child(col)
	floor_snap_length = 0.35
	_build_human()
	_build_blob()
	drips = _particles(14, 0.7, false)
	add_child(drips)
	splash = _particles(36, 0.9, true)
	splash.top_level = true
	add_child(splash)

func _build_human() -> void:
	rig = Node3D.new()
	add_child(rig)
	var skin := Color.from_hsv(randf_range(0.04, 0.1), randf_range(0.25, 0.55), randf_range(0.65, 0.95))
	var shirt := Color.from_hsv(randf(), 0.6, 0.85)
	var pants := Color.from_hsv(randf_range(0.55, 0.7), 0.5, 0.4)
	var hair := Color.from_hsv(randf_range(0.04, 0.12), 0.6, randf_range(0.1, 0.45))
	var shoe := Color(0.1, 0.1, 0.12)
	# ---- far LOD: 3 boxes ----
	_box(rig, Vector3(0.5, 0.9, 0.28), Vector3(0, 0.45, 0), pants, false)
	_box(rig, Vector3(0.56, 0.62, 0.3), Vector3(0, 1.21, 0), shirt, false)
	_box(rig, Vector3(0.38, 0.38, 0.38), Vector3(0, 1.74, 0), skin, false)
	# ---- near LOD: articulated ----
	torso = _pivot(rig, Vector3(0, 0.9, 0))
	_box(torso, Vector3(0.56, 0.62, 0.3), Vector3(0, 0.31, 0), shirt)
	_box(torso, Vector3(0.58, 0.1, 0.32), Vector3(0, 0.03, 0), Color(0.15, 0.15, 0.18))
	head = _pivot(torso, Vector3(0, 0.64, 0))
	_box(head, Vector3(0.38, 0.38, 0.38), Vector3(0, 0.2, 0), skin)
	_box(head, Vector3(0.4, 0.12, 0.4), Vector3(0, 0.4, 0), hair)
	_box(head, Vector3(0.4, 0.24, 0.1), Vector3(0, 0.27, 0.16), hair)
	_box(head, Vector3(0.07, 0.07, 0.02), Vector3(-0.09, 0.22, -0.19), Color.BLACK)
	_box(head, Vector3(0.07, 0.07, 0.02), Vector3(0.09, 0.22, -0.19), Color.BLACK)
	for s in [-1.0, 1.0]:
		var sh := _pivot(torso, Vector3(s * 0.37, 0.56, 0))
		_box(sh, Vector3(0.16, 0.36, 0.16), Vector3(0, -0.18, 0), shirt)
		var el := _pivot(sh, Vector3(0, -0.36, 0))
		_box(el, Vector3(0.15, 0.32, 0.15), Vector3(0, -0.16, 0), skin)
		_box(el, Vector3(0.16, 0.1, 0.16), Vector3(0, -0.35, 0), skin)
		arms.append(sh)
		elbows.append(el)
		var hip := _pivot(rig, Vector3(s * 0.15, 0.9, 0))
		_box(hip, Vector3(0.26, 0.45, 0.26), Vector3(0, -0.225, 0), pants)
		var kn := _pivot(hip, Vector3(0, -0.45, 0))
		_box(kn, Vector3(0.24, 0.4, 0.24), Vector3(0, -0.2, 0), pants)
		_box(kn, Vector3(0.26, 0.1, 0.38), Vector3(0, -0.4, -0.06), shoe)
		legs.append(hip)
		knees.append(kn)

func _build_blob() -> void:
	blob = Node3D.new()
	blob.visible = false
	add_child(blob)
	var o := SphereMesh.new()
	o.radius = 0.7
	o.height = 1.4
	o.radial_segments = 20
	o.rings = 10
	var mo := MeshInstance3D.new()
	mo.mesh = o
	mo.material_override = water_mat()
	mo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.add_child(mo)
	var i := SphereMesh.new()
	i.radius = 0.42
	i.height = 0.84
	i.radial_segments = 12
	i.rings = 6
	var core := StandardMaterial3D.new()
	core.albedo_color = Color(0.04, 0.3, 0.85, 0.85)
	core.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mc := MeshInstance3D.new()
	mc.mesh = i
	mc.material_override = core
	mc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.add_child(mc)

func _particles(n: int, life: float, burst: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.emitting = false
	p.one_shot = burst
	p.explosiveness = 0.95 if burst else 0.0
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	sm.radial_segments = 6
	sm.rings = 3
	p.mesh = sm
	p.material_override = water_mat()
	p.direction = Vector3.UP
	p.spread = 55.0 if burst else 30.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.5 if burst else 2.0
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	p.local_coords = false
	if not burst:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.4
	return p

func splash_at(y: float, strong: bool) -> void:
	splash.global_position = Vector3(global_position.x, y, global_position.z)
	splash.initial_velocity_max = 7.0 if strong else 4.0
	splash.restart()
	splash.emitting = true
	splashed.emit(self, strong)

func set_water(on: bool) -> void:
	if water_form == on:
		return
	water_form = on
	cap.radius = 0.5 if on else 0.35
	cap.height = 1.4 if on else 1.8
	col.position.y = cap.height * 0.5
	splash_at(global_position.y + 0.1, false)

func _ai(delta: float) -> bool:
	ai_t -= delta
	if in_water:
		ai_dir = Vector3(0, 0, 0.7)
		return true
	var p := global_position - POOL_C
	if ai_t <= 0.0:
		ai_t = randf_range(1.5, 4.0)
		ai_dir = Vector3.ZERO if randf() < 0.3 else Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * 0.5
	if absf(p.x) < POOL_H + 2.5 and absf(p.z) < POOL_H + 2.5:
		ai_dir = Vector3(p.x, 0, p.z).normalized() * 0.5
	if absf(global_position.x) > 34.0 or absf(global_position.z) > 34.0:
		ai_dir = Vector3(-global_position.x, 0, -global_position.z).normalized() * 0.5
	return false

func _physics_process(delta: float) -> void:
	var p := global_position - POOL_C
	var was_in := in_water
	in_water = absf(p.x) < POOL_H and absf(p.z) < POOL_H and global_position.y < WATER_Y + 0.1
	var dir := Vector3.ZERO
	var jump := false
	if controlled:
		dir = Vector3(move_input.x, 0, move_input.y).rotated(Vector3.UP, cam_yaw)
		jump = want_jump
	else:
		jump = _ai(delta)
		dir = ai_dir
	if dir.length() > 1.0:
		dir = dir.normalized()
	var top := 7.0
	var rate := 9.0 if is_on_floor() else 3.0
	if water_form:
		top = 9.5
		rate = 3.5
	elif in_water:
		top = 3.2
		rate = 3.5
	var k := 1.0 - exp(-rate * delta)
	velocity.x = lerpf(velocity.x, dir.x * top, k)
	velocity.z = lerpf(velocity.z, dir.z * top, k)
	if in_water:
		if velocity.y > 1.0:
			velocity.y -= GRAV * delta
		else:
			var ty := WATER_Y - (0.8 if water_form else 1.05)
			velocity.y += ((ty - global_position.y) * 30.0 - velocity.y * 6.0) * delta
		if jump:
			velocity.y = 6.0 if water_form else 8.8
	else:
		if not is_on_floor():
			velocity.y -= GRAV * delta
		elif jump:
			velocity.y = 7.0 if water_form else 8.8
	var vy := velocity.y
	move_and_slide()
	var gp := global_position
	global_position = Vector3(clampf(gp.x, -38.0, 38.0), gp.y, clampf(gp.z, -38.0, 38.0))
	var fl := is_on_floor()
	if in_water and not was_in:
		splash_at(WATER_Y, vy < -4.0)
	if fl and not was_floor and vy < -5.0:
		squash = clampf(-vy / 14.0, 0.0, 1.0)
		stepped.emit(self, false)
	was_floor = fl
	var spd := Vector2(velocity.x, velocity.z).length()
	if (fl or in_water) and spd > 1.0 and not water_form:
		step_acc += spd * delta
		if step_acc > 1.7:
			step_acc = 0.0
			stepped.emit(self, in_water)
	if spd > 0.5:
		yaw = atan2(-velocity.x, -velocity.z)
	# Health: water form burns energy on land, refills in the pool
	if water_form and not in_water:
		health -= 3.0 * delta
	elif water_form:
		health = minf(100.0, health + 8.0 * delta)
	else:
		health = minf(100.0, health + 2.0 * delta)
	if health <= 0.0:
		health = 0.0
		set_water(false)

func _process(delta: float) -> void:
	t += delta
	squash = move_toward(squash, 0.0, delta * 3.0)
	morph = move_toward(morph, 1.0 if water_form else 0.0, delta * 3.5)
	var spd := Vector2(velocity.x, velocity.z).length()
	var cam := get_viewport().get_camera_3d()
	var d := 0.0 if cam == null else cam.global_position.distance_to(global_position)
	var e := morph * morph * (3.0 - 2.0 * morph)
	rig.visible = morph < 0.98
	blob.visible = morph > 0.02
	rig.rotation.y = lerp_angle(rig.rotation.y, yaw, 1.0 - exp(-12.0 * delta))
	if rig.visible:
		var hs := maxf(1.0 - e, 0.02)
		rig.scale = Vector3(1.0 + squash * 0.1, 1.0 - squash * 0.16, 1.0 + squash * 0.1) * hs
		if d < LOD_DIST:
			_animate(delta, spd)
	if blob.visible:
		var w := sin(t * 5.0) * 0.07 + sin(t * 8.3) * 0.03
		var st := clampf(spd / 10.0, 0.0, 0.4)
		blob.rotation.y = rig.rotation.y
		blob.scale = Vector3(1.0 + w - st * 0.3, 1.0 - w * 1.2 - st * 0.25 - squash * 0.25, 1.0 + st * 0.6 + w) * maxf(e, 0.02)
		blob.position.y = 0.7 * blob.scale.y
	drips.emitting = water_form and spd > 2.0 and not in_water

func _r(n: Node3D, a: float, k: float) -> void:
	n.rotation.x = lerpf(n.rotation.x, a, k)

func _animate(delta: float, spd: float) -> void:
	var k := 1.0 - exp(-16.0 * delta)
	var amp := clampf(spd / 5.5, 0.0, 1.0)
	if spd > 0.3:
		phase += delta * (2.0 + spd * 1.25)
	var sl := sin(phase)
	var cl := cos(phase)
	var by := 0.0
	if not is_on_floor() and not in_water:
		_r(legs[0], 0.7, k); _r(legs[1], -0.4, k)
		_r(knees[0], -1.0, k); _r(knees[1], -0.3, k)
		_r(arms[0], 2.2, k); _r(arms[1], 1.7, k)
		_r(elbows[0], 0.4, k); _r(elbows[1], 0.4, k)
		_r(torso, -0.08, k); _r(head, 0.05, k)
		torso.rotation.y = lerpf(torso.rotation.y, 0.0, k)
	elif in_water:
		var f := sin(phase * 1.4) * 0.55 * maxf(amp, 0.3)
		_r(legs[0], f, k); _r(legs[1], -f, k)
		_r(knees[0], -0.35, k); _r(knees[1], -0.35, k)
		_r(arms[0], 1.6 + sin(phase * 0.9) * 0.9, k)
		_r(arms[1], 1.6 - sin(phase * 0.9) * 0.9, k)
		_r(elbows[0], 0.5, k); _r(elbows[1], 0.5, k)
		_r(torso, -0.1 - 0.7 * amp, k); _r(head, 0.5 * amp, k)
		by = sin(t * 3.0) * 0.05
	else:
		_r(legs[0], sl * 0.85 * amp, k); _r(legs[1], -sl * 0.85 * amp, k)
		_r(knees[0], -maxf(0.0, cl) * amp, k); _r(knees[1], -maxf(0.0, -cl) * amp, k)
		_r(arms[0], -sl * 0.75 * amp + sin(t * 1.6) * 0.04, k)
		_r(arms[1], sl * 0.75 * amp - sin(t * 1.6) * 0.04, k)
		_r(elbows[0], 0.15 + 0.7 * amp, k); _r(elbows[1], 0.15 + 0.7 * amp, k)
		_r(torso, -0.14 * amp, k); _r(head, 0.08 * amp, k)
		torso.rotation.y = lerpf(torso.rotation.y, sl * 0.14 * amp, k)
		by = absf(cl) * 0.07 * amp
		torso.scale.y = 1.0 + sin(t * 2.2) * 0.012
	rig.position.y = lerpf(rig.position.y, by, k)
