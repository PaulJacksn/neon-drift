extends Node3D
## Endless neon tunnel: pulsing rings, guide rails, speed streaks, starfield.
## Rings and streaks move toward the camera and wrap around.

const RING_COUNT := 18
const RING_SPACING := 6.0
const FIRST_RING_Z := -12.0
const WRAP_Z := -8.0
const TUNNEL_RADIUS := 5.5
const STREAK_COUNT := 26

var _rings: Array[Node3D] = []
var _streaks: Array[MeshInstance3D] = []
var _cyan_mat: StandardMaterial3D
var _magenta_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_cyan_mat = _neon_mat(Color(0.0, 0.94, 1.0))
	_magenta_mat = _neon_mat(Color(1.0, 0.17, 0.84))
	_build_rings()
	_build_rails()
	_build_streaks()
	_build_starfield()

func _neon_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m

func _build_rings() -> void:
	var outer := TorusMesh.new()
	outer.inner_radius = 5.32
	outer.outer_radius = 5.5
	outer.rings = 48
	outer.ring_segments = 8
	var accent := TorusMesh.new()
	accent.inner_radius = 5.0
	accent.outer_radius = 5.08
	accent.rings = 48
	accent.ring_segments = 6
	for i in RING_COUNT:
		var ring := Node3D.new()
		ring.position.z = FIRST_RING_Z - float(i) * RING_SPACING
		var main := MeshInstance3D.new()
		main.mesh = outer
		main.rotation.x = PI / 2.0
		main.material_override = _cyan_mat if i % 2 == 0 else _magenta_mat
		ring.add_child(main)
		var acc := MeshInstance3D.new()
		acc.mesh = accent
		acc.rotation.x = PI / 2.0
		acc.material_override = _magenta_mat if i % 2 == 0 else _cyan_mat
		ring.add_child(acc)
		add_child(ring)
		_rings.append(ring)

func _build_rails() -> void:
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(0.12, 0.12, 130.0)
	var purple := _neon_mat(Color(0.23, 0.1, 0.45))
	var teal := _neon_mat(Color(0.04, 0.35, 0.45))
	for k in 6:
		var angle := TAU * float(k) / 6.0
		var rail := MeshInstance3D.new()
		rail.mesh = rail_mesh
		rail.material_override = purple if k % 2 == 0 else teal
		rail.position = Vector3(cos(angle) * 5.35, sin(angle) * 5.35, -58.0)
		add_child(rail)

func _build_streaks() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, 2.2)
	var mat := _neon_mat(Color(0.75, 0.95, 1.0))
	for i in STREAK_COUNT:
		var s := MeshInstance3D.new()
		s.mesh = mesh
		s.material_override = mat
		var angle := _rng.randf_range(0.0, TAU)
		var radius := _rng.randf_range(3.0, 5.0)
		s.position = Vector3(cos(angle) * radius, sin(angle) * radius, _rng.randf_range(-112.0, -8.0))
		add_child(s)
		_streaks.append(s)

func _build_starfield() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 180
	particles.lifetime = 8.0
	particles.local_coords = false
	particles.position = Vector3(0, 0, -60)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28, 28, 55)
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 0.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.05
	pm.scale_max = 0.13
	pm.color = Color(0.85, 0.9, 1.0)
	particles.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	quad.material = _neon_mat(Color(0.9, 0.95, 1.0))
	particles.draw_pass_1 = quad
	add_child(particles)

## Called every frame by main. beat_phase 0..1, pulse 0..1 right after a beat.
func update_world(dt: float, speed: float, beat_phase: float, pulse: float) -> void:
	var dz := speed * dt
	# Rings travel toward the camera and wrap, with a traveling beat wave.
	for i in _rings.size():
		var ring := _rings[i]
		ring.position.z += dz
		if ring.position.z > WRAP_Z:
			ring.position.z -= RING_COUNT * RING_SPACING
		var wave := sin(beat_phase * TAU - float(i) * 0.9)
		var s := 1.0 + 0.045 * wave * (0.4 + 0.6 * pulse)
		ring.scale = Vector3(s, s, 1.0)
	# Shared material brightness pulses on the beat.
	var bright := 0.8 + 0.35 * pulse
	_cyan_mat.albedo_color = Color(0.0, 0.94 * bright, 1.0 * bright)
	_magenta_mat.albedo_color = Color(1.0 * bright, 0.17 * bright, 0.84 * bright)
	# Streaks rush past faster than the world.
	var speed_ratio := clampf(speed / 55.0, 0.0, 1.0)
	for streak in _streaks:
		streak.position.z += dz * 2.1
		if streak.position.z > -6.0:
			streak.position.z -= 104.0
		streak.scale.z = 1.0 + speed_ratio * 1.6

func reset() -> void:
	for i in _rings.size():
		_rings[i].position.z = FIRST_RING_Z - float(i) * RING_SPACING
		_rings[i].scale = Vector3.ONE
