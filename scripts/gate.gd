extends Node3D
## Score ring. Fly through the center to score; the ring spins slowly.

var active: bool = false
var counted: bool = false
var center := Vector2.ZERO

var _ring: Node3D
var _spin := 0.0

func _ready() -> void:
	_ring = Node3D.new()
	add_child(_ring)
	var cyan := StandardMaterial3D.new()
	cyan.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cyan.albedo_color = Color(0.15, 0.95, 1.0)
	var torus := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.3
	tm.outer_radius = 1.52
	tm.rings = 40
	tm.ring_segments = 10
	torus.mesh = tm
	torus.rotation.x = PI / 2.0
	torus.material_override = cyan
	_ring.add_child(torus)
	# Faint energy disc across the opening
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 1.3
	dm.bottom_radius = 1.3
	dm.height = 0.02
	dm.radial_segments = 32
	disc.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.albedo_color = Color(0.15, 0.9, 1.0, 0.08)
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material_override = dmat
	disc.rotation.x = PI / 2.0
	_ring.add_child(disc)
	# Gold beads on the ring so the spin reads
	var gold := StandardMaterial3D.new()
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.albedo_color = Color(1.0, 0.84, 0.37)
	for k in 4:
		var angle := TAU * float(k) / 4.0
		var bead := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.13
		sm.height = 0.26
		bead.mesh = sm
		bead.material_override = gold
		bead.position = Vector3(cos(angle) * 1.41, sin(angle) * 1.41, 0)
		_ring.add_child(bead)
	visible = false

func setup(pos: Vector2) -> void:
	center = pos
	position = Vector3(pos.x, pos.y, position.z)
	active = true
	counted = false
	visible = true
	_spin = randf() * TAU

func update_gate(dt: float, time: float) -> void:
	_spin += dt * 0.8
	_ring.rotation.z = _spin
	var s := 1.0 + 0.05 * sin(time * 3.0)
	_ring.scale = Vector3(s, s, 1.0)

func deactivate() -> void:
	active = false
	visible = false
