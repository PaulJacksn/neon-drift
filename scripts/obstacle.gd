extends Node3D
## Barrier obstacle. Patterns always leave a passable gap.
## Collision rects are exposed for the main script to test.

enum Pattern { SINGLE, PAIR, BAR_H, BAR_V, CROSS }

var active: bool = false
var counted: bool = false
var centers: Array[Vector2] = []
var halfs: Array[Vector2] = []

var _boxes: Array[MeshInstance3D] = []
var _edge_boxes: Array[MeshInstance3D] = []
var _cores: Array[MeshInstance3D] = []

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.08, 0.14)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.1, 0.2)
	mat.emission_energy_multiplier = 2.2
	var edge := StandardMaterial3D.new()
	edge.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge.albedo_color = Color(1.0, 0.55, 0.2)
	var core := StandardMaterial3D.new()
	core.albedo_color = Color(0.05, 0.02, 0.05)
	core.metallic = 0.3
	core.roughness = 0.6
	for i in 2:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		box.mesh = mesh
		box.material_override = mat
		add_child(box)
		_boxes.append(box)
		var eb := MeshInstance3D.new()
		var emesh := BoxMesh.new()
		emesh.size = Vector3.ONE
		eb.mesh = emesh
		eb.material_override = edge
		add_child(eb)
		_edge_boxes.append(eb)
		var cb := MeshInstance3D.new()
		var cmesh := BoxMesh.new()
		cmesh.size = Vector3.ONE
		cb.mesh = cmesh
		cb.material_override = core
		add_child(cb)
		_cores.append(cb)
	visible = false

func _place(idx: int, center: Vector2, size: Vector2) -> void:
	_boxes[idx].visible = true
	_boxes[idx].position = Vector3(center.x, center.y, 0)
	_boxes[idx].scale = Vector3(size.x, size.y, 1.0)
	_edge_boxes[idx].visible = true
	_edge_boxes[idx].position = Vector3(center.x, center.y, -0.52)
	_edge_boxes[idx].scale = Vector3(size.x + 0.12, 0.12, 0.06)
	_cores[idx].visible = true
	_cores[idx].position = Vector3(center.x, center.y, -0.53)
	_cores[idx].scale = Vector3(size.x * 0.72, size.y * 0.72, 0.06)
	centers.append(center)
	halfs.append(size * 0.5)

func setup(pattern: int, rng: RandomNumberGenerator) -> void:
	centers.clear()
	halfs.clear()
	_boxes[0].visible = false
	_boxes[1].visible = false
	_edge_boxes[0].visible = false
	_edge_boxes[1].visible = false
	_cores[0].visible = false
	_cores[1].visible = false
	match pattern:
		Pattern.SINGLE:
			var pos := Vector2(rng.randf_range(-2.6, 2.6), rng.randf_range(-2.6, 2.6))
			_place(0, pos, Vector2(2.4, 2.4))
		Pattern.PAIR:
			var a := Vector2(rng.randf_range(-2.8, 0.4), rng.randf_range(-2.6, 2.6))
			var b := Vector2(rng.randf_range(0.8, 2.8), rng.randf_range(-2.6, 2.6))
			_place(0, a, Vector2(2.0, 2.0))
			_place(1, b, Vector2(2.0, 2.0))
		Pattern.BAR_H:
			var y := 2.6 if rng.randf() < 0.5 else -2.6
			_place(0, Vector2(0, y), Vector2(8.0, 1.7))
		Pattern.BAR_V:
			var x := 2.6 if rng.randf() < 0.5 else -2.6
			_place(0, Vector2(x, 0), Vector2(1.7, 8.0))
		Pattern.CROSS:
			var y := 2.6 if rng.randf() < 0.5 else -2.6
			var x := -2.6 if y > 0.0 else 2.6
			_place(0, Vector2(0, y), Vector2(8.0, 1.7))
			_place(1, Vector2(x, 0), Vector2(1.7, 8.0))
	active = true
	counted = false
	visible = true

func deactivate() -> void:
	active = false
	visible = false
