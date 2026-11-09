extends Node3D
## Player hover-ship: built from primitives, banks into turns, engine trail.

var velocity := Vector2.ZERO
var _hover_time := 0.0
var _body: Node3D
var _trail: GPUParticles3D

func _ready() -> void:
	scale = Vector3(1.25, 1.25, 1.25)
	_body = Node3D.new()
	add_child(_body)
	_build_ship()
	_build_trail()

func _shaded(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

func _neon(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m

func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_z: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation.z = rot_z
	parent.add_child(mi)
	return mi

func _build_ship() -> void:
	var hull := _shaded(Color(0.22, 0.22, 0.38), 0.7, 0.35)
	var cyan := _neon(Color(0.0, 0.94, 1.0))
	var pink := _neon(Color(1.0, 0.17, 0.84))
	var gold := _neon(Color(1.0, 0.84, 0.37))
	# Small cyan light so the ship reads against the dark void
	var light := OmniLight3D.new()
	light.light_color = Color(0.2, 0.8, 1.0)
	light.light_energy = 2.0
	light.omni_range = 7.0
	light.position = Vector3(0, 0.6, -0.3)
	_body.add_child(light)
	# Main hull
	_add_box(_body, Vector3(0.55, 0.16, 1.7), Vector3(0, 0, 0), hull)
	# Nose cone (flattened, pointing forward -Z)
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.27
	cm.height = 0.75
	cm.radial_segments = 8
	cone.mesh = cm
	cone.material_override = hull
	cone.rotation.x = -PI / 2.0
	cone.scale = Vector3(1.0, 1.0, 0.32)
	cone.position = Vector3(0, 0, -1.2)
	_body.add_child(cone)
	# Wings, swept back and slightly angled
	_add_box(_body, Vector3(1.15, 0.05, 0.55), Vector3(-0.62, -0.02, 0.42), hull, 0.18)
	_add_box(_body, Vector3(1.15, 0.05, 0.55), Vector3(0.62, -0.02, 0.42), hull, -0.18)
	# Neon wing-tip strips (thick, so they read at speed)
	_add_box(_body, Vector3(1.15, 0.09, 0.09), Vector3(-0.62, -0.02, 0.68), pink, 0.18)
	_add_box(_body, Vector3(1.15, 0.09, 0.09), Vector3(0.62, -0.02, 0.68), pink, -0.18)
	# Cockpit canopy
	var canopy := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.3
	canopy.mesh = sm
	canopy.material_override = cyan
	canopy.position = Vector3(0, 0.12, -0.25)
	canopy.scale = Vector3(1.0, 0.7, 1.6)
	_body.add_child(canopy)
	# Hull spine light
	_add_box(_body, Vector3(0.08, 0.03, 1.2), Vector3(0, 0.09, 0.1), cyan)
	# Engine glow orbs
	for x in [-0.18, 0.18]:
		var orb := MeshInstance3D.new()
		var om := SphereMesh.new()
		om.radius = 0.09
		om.height = 0.18
		orb.mesh = om
		orb.material_override = gold
		orb.position = Vector3(x, 0, 0.88)
		_body.add_child(orb)

func _build_trail() -> void:
	_trail = GPUParticles3D.new()
	_trail.amount = 48
	_trail.lifetime = 0.45
	_trail.local_coords = true
	_trail.position = Vector3(0, 0, 0.9)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.12
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 10.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.06
	pm.scale_max = 0.16
	pm.color = Color(0.2, 0.9, 1.0)
	_trail.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	quad.material = _neon(Color(0.2, 0.9, 1.0))
	_trail.draw_pass_1 = quad
	add_child(_trail)

## Steer toward target (world x/y), bank into the turn, bob while hovering.
func update_ship(dt: float, target: Vector2, speed_ratio: float, hovering: bool, pulse: float) -> void:
	_hover_time += dt
	var prev := Vector2(position.x, position.y)
	var rate := 7.0 if hovering else 13.0
	var nx := lerpf(position.x, target.x, 1.0 - exp(-rate * dt))
	var ny := lerpf(position.y, target.y, 1.0 - exp(-rate * dt))
	if hovering:
		ny += sin(_hover_time * 2.0) * 0.0015
	position.x = nx
	position.y = ny
	velocity = (Vector2(nx, ny) - prev) / maxf(dt, 0.0001)
	# Bank: roll into lateral motion, pitch with vertical motion.
	var target_roll := clampf(-velocity.x * 0.045, -0.55, 0.55)
	var target_pitch := clampf(velocity.y * 0.03, -0.3, 0.3)
	_body.rotation.z = lerpf(_body.rotation.z, target_roll, 1.0 - exp(-10.0 * dt))
	_body.rotation.x = lerpf(_body.rotation.x, target_pitch, 1.0 - exp(-10.0 * dt))
	# Trail gets denser and longer with speed, and pulses on the beat.
	_trail.amount_ratio = 0.5 + speed_ratio * 0.4 + pulse * 0.2

func set_visible_ship(visible: bool) -> void:
	_body.visible = visible
	_trail.emitting = visible

func reset() -> void:
	position = Vector3(0, 0, position.z)
	velocity = Vector2.ZERO
	_body.rotation = Vector3.ZERO
	set_visible_ship(true)
