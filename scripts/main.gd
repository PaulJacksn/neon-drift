extends Node3D
## Neon Drift: game controller. State machine, spawning, collisions, scoring,
## camera feel, FX, audio wiring, persistence, web debug hook.

const AudioScript = preload("res://scripts/audio.gd")
const TunnelScript = preload("res://scripts/tunnel.gd")
const ShipScript = preload("res://scripts/ship.gd")
const ObstacleScript = preload("res://scripts/obstacle.gd")
const GateScript = preload("res://scripts/gate.gd")
const HudScript = preload("res://scripts/hud.gd")

const PLAYER_Z := -6.0
const SPAWN_Z := -120.0
const DESPAWN_Z := 10.0
const BASE_SPEED := 18.0
const MAX_SPEED := 55.0
const ACCEL := 0.45
const PLAYER_LIMIT := 4.0
const STEER_SENS := 0.012
const HIT_RADIUS := 0.5
const GATE_HIT_RADIUS := 1.35
const NEAR_MISS_DIST := 1.4
const SAVE_PATH := "user://neon_drift_save.cfg"

enum State { MENU, PLAYING, PAUSED, GAMEOVER }

var state: int = State.MENU
var speed := 0.0
var score := 0.0
var best_score := 0
var combo := 0
var combo_mult := 1
var time_played := 0.0
var _shake := 0.0
var _fov_punch := 0.0
var _speed_boost := 0.0
var _time := 0.0
var _beat_timer := 0.0
var _target := Vector2.ZERO
var _dragging := false
var _crash_timer := 0.0
var _panel_shown := false
var _is_new_best := false
var _debug_timer := 0.0
var _last_hud_score := -1
var _rng := RandomNumberGenerator.new()
var _obstacle_timer := 1.2
var _gate_timer := 2.0

var _camera: Camera3D
var _tunnel: Node3D
var _ship: Node3D
var _audio: Node
var _hud: CanvasLayer
var _obstacles: Array = []
var _gates: Array = []
var _gate_burst: GPUParticles3D
var _explosion: GPUParticles3D
var _flash_light: OmniLight3D

func _ready() -> void:
	_rng.randomize()
	_load_best()
	_build_environment()
	_build_camera()
	_tunnel = TunnelScript.new()
	add_child(_tunnel)
	_ship = ShipScript.new()
	_ship.position = Vector3(0, 0, PLAYER_Z)
	add_child(_ship)
	_audio = AudioScript.new()
	add_child(_audio)
	_hud = HudScript.new()
	add_child(_hud)
	_hud.pause_pressed.connect(_on_pause_pressed)
	_hud.resume_pressed.connect(_on_resume_pressed)
	_hud.restart_pressed.connect(start_game)
	_hud.set_best(best_score)
	_build_pools()
	_build_fx()
	_hud.show_menu()

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.005, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.3, 0.5)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = 1.3
	env.glow_bloom = 0.06
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.05, 0.02, 0.12)
	env.fog_depth_begin = 14.0
	env.fog_depth_end = 80.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.85, 0.9, 1.0)
	sun.light_energy = 0.7
	sun.rotation = Vector3(-0.5, 0.2, 0.0)
	add_child(sun)

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 68.0
	_camera.near = 0.1
	_camera.far = 220.0
	_camera.position = Vector3.ZERO
	add_child(_camera)

func _build_pools() -> void:
	for i in 12:
		var ob = ObstacleScript.new()
		add_child(ob)
		_obstacles.append(ob)
	for i in 8:
		var g = GateScript.new()
		add_child(g)
		_gates.append(g)

func _build_fx() -> void:
	_gate_burst = _make_burst(80, 0.6, Color(0.2, 0.95, 1.0), 3.0, 8.0)
	add_child(_gate_burst)
	_explosion = _make_burst(140, 0.9, Color(1.0, 0.45, 0.15), 4.0, 14.0)
	add_child(_explosion)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.5, 0.2)
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 18.0
	_flash_light.position = Vector3(0, 0, PLAYER_Z)
	add_child(_flash_light)

func _make_burst(amount: int, lifetime: float, color: Color, vel_min: float, vel_max: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.2
	pm.direction = Vector3(0, 0, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = vel_min
	pm.initial_velocity_max = vel_max
	pm.gravity = Vector3(0, -2, 0)
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.scale_min = 0.08
	pm.scale_max = 0.22
	pm.color = color
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	quad.material = mat
	p.draw_pass_1 = quad
	return p

# ---------------------------------------------------------------- state flow

func start_game() -> void:
	score = 0.0
	combo = 0
	combo_mult = 1
	time_played = 0.0
	speed = BASE_SPEED
	_target = Vector2.ZERO
	_shake = 0.0
	_fov_punch = 0.0
	_speed_boost = 0.0
	_is_new_best = false
	_panel_shown = false
	_last_hud_score = -1
	for ob in _obstacles:
		ob.deactivate()
	for g in _gates:
		g.deactivate()
	_tunnel.reset()
	_ship.reset()
	_ship.position = Vector3(0, 0, PLAYER_Z)
	_obstacle_timer = 1.4
	_gate_timer = 2.2
	_beat_timer = 0.0
	_audio.duck_music(false)
	_audio.start_music()
	state = State.PLAYING
	_hud.show_hud()
	_hud.set_combo(0, 1)
	_hud.set_speed_ratio(0.0)

func _crash() -> void:
	if state != State.PLAYING:
		return
	state = State.GAMEOVER
	_crash_timer = 0.9
	_panel_shown = false
	var ship_pos := Vector3(_ship.position.x, _ship.position.y, PLAYER_Z)
	_explosion.position = ship_pos
	_explosion.restart()
	_flash_light.position = ship_pos
	_flash_light.light_energy = 12.0
	_hud.flash()
	_audio.play_thud()
	_audio.duck_music(true)
	_shake = 1.3
	_ship.set_visible_ship(false)
	Input.vibrate_handheld(200)
	_is_new_best = int(score) > best_score
	if _is_new_best:
		best_score = int(score)
		_save_best()
		_hud.set_best(best_score)

func _on_pause_pressed() -> void:
	if state == State.PLAYING:
		state = State.PAUSED
		_hud.show_pause()
		_audio.duck_music(true)

func _on_resume_pressed() -> void:
	if state == State.PAUSED:
		state = State.PLAYING
		_hud.hide_pause()
		_audio.duck_music(false)

# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			match state:
				State.MENU:
					start_game()
				State.GAMEOVER:
					if _panel_shown:
						start_game()
				State.PLAYING:
					_dragging = true
		else:
			_dragging = false
	elif event is InputEventScreenDrag:
		if state == State.PLAYING and _dragging:
			var drag := event as InputEventScreenDrag
			_target += Vector2(drag.relative.x, -drag.relative.y) * STEER_SENS
			if _target.length() > PLAYER_LIMIT:
				_target = _target.normalized() * PLAYER_LIMIT
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			match key.keycode:
				KEY_SPACE, KEY_ENTER:
					if state == State.MENU:
						start_game()
					elif state == State.GAMEOVER and _panel_shown:
						start_game()
				KEY_P, KEY_ESCAPE:
					if state == State.PLAYING:
						_on_pause_pressed()
					elif state == State.PAUSED:
						_on_resume_pressed()

# ---------------------------------------------------------------- per-frame

func _process(delta: float) -> void:
	_time += delta
	match state:
		State.MENU:
			_update_menu(delta)
		State.PLAYING:
			_update_playing(delta)
		State.GAMEOVER:
			_update_gameover(delta)
	_debug_timer += delta
	if _debug_timer >= 0.25:
		_debug_timer = 0.0
		_update_debug_hook()

func _beat_values(dt: float) -> Vector2:
	var pos: float = _audio.music_position()
	var phase: float
	if pos >= 0.0:
		phase = fmod(pos, AudioScript.BEAT_LEN) / AudioScript.BEAT_LEN
	else:
		_beat_timer += dt
		phase = fmod(_beat_timer, AudioScript.BEAT_LEN) / AudioScript.BEAT_LEN
	return Vector2(phase, pow(1.0 - phase, 2.0))

func _update_menu(delta: float) -> void:
	var beat := _beat_values(delta)
	_tunnel.update_world(delta, 8.0, beat.x, beat.y)
	_ship.update_ship(delta, Vector2.ZERO, 0.0, true, beat.y)
	_camera.fov = lerpf(_camera.fov, 68.0, 1.0 - exp(-3.0 * delta))

func _update_playing(delta: float) -> void:
	time_played += delta
	_speed_boost = maxf(0.0, _speed_boost - delta * 1.5)
	speed = minf(MAX_SPEED, BASE_SPEED + ACCEL * time_played + _speed_boost)
	var ratio := (speed - BASE_SPEED) / (MAX_SPEED - BASE_SPEED)
	score += speed * delta * 0.5
	# Music may have finished generating after the tap; start it when ready.
	if not _audio.music_player.playing:
		_audio.start_music()
	var beat := _beat_values(delta)
	_tunnel.update_world(delta, speed, beat.x, beat.y)
	_ship.update_ship(delta, _target, ratio, false, beat.y)
	_update_spawning(delta, ratio)
	_update_entities(delta, true)
	_update_camera(delta, ratio)
	# HUD
	var shown := int(score)
	if shown != _last_hud_score:
		_last_hud_score = shown
		_hud.set_score(shown)
	_hud.set_speed_ratio(ratio)

func _update_gameover(delta: float) -> void:
	speed = maxf(0.0, speed - delta * 30.0)
	var beat := _beat_values(delta)
	_tunnel.update_world(delta, speed, beat.x, beat.y)
	_update_entities(delta, false)
	_shake = maxf(0.0, _shake - delta * 2.0)
	_camera.position = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0) * _shake * 0.3
	_flash_light.light_energy = maxf(0.0, _flash_light.light_energy - delta * 20.0)
	_crash_timer -= delta
	if _crash_timer <= 0.0 and not _panel_shown:
		_panel_shown = true
		_hud.show_gameover(int(score), best_score, _is_new_best)

func _update_camera(delta: float, ratio: float) -> void:
	_fov_punch = maxf(0.0, _fov_punch - delta * 10.0)
	var target_fov := 68.0 + ratio * 22.0 + _fov_punch
	_camera.fov = lerpf(_camera.fov, target_fov, 1.0 - exp(-3.0 * delta))
	_shake = maxf(0.0, _shake - delta * 2.2)
	_camera.position = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0) * _shake * 0.3
	_camera.rotation.z = -_ship.position.x * 0.012

# ---------------------------------------------------------------- spawning

func _update_spawning(delta: float, ratio: float) -> void:
	_obstacle_timer -= delta
	if _obstacle_timer <= 0.0:
		_spawn_obstacle()
		_obstacle_timer = lerpf(1.7, 0.95, ratio) * _rng.randf_range(0.85, 1.2)
	_gate_timer -= delta
	if _gate_timer <= 0.0:
		_spawn_gate()
		_gate_timer = _rng.randf_range(2.6, 4.0)

func _spawn_obstacle() -> void:
	for ob in _obstacles:
		if not ob.active:
			var patterns: Array[int] = [ObstacleScript.Pattern.SINGLE, ObstacleScript.Pattern.PAIR]
			if time_played > 12.0:
				patterns.append(ObstacleScript.Pattern.BAR_H)
				patterns.append(ObstacleScript.Pattern.BAR_V)
			if time_played > 35.0:
				patterns.append(ObstacleScript.Pattern.CROSS)
			var p: int = patterns[_rng.randi_range(0, patterns.size() - 1)]
			ob.setup(p, _rng)
			ob.position = Vector3(0, 0, SPAWN_Z)
			return

func _spawn_gate() -> void:
	for g in _gates:
		if not g.active:
			var pos := Vector2(_rng.randf_range(-2.8, 2.8), _rng.randf_range(-2.8, 2.8))
			g.setup(pos)
			g.position.z = SPAWN_Z - 10.0
			return

# ---------------------------------------------------------------- entities + collisions

func _update_entities(delta: float, check_collisions: bool) -> void:
	var dz := speed * delta
	var ship_xy := Vector2(_ship.position.x, _ship.position.y)
	for ob in _obstacles:
		if not ob.active:
			continue
		var prev_z: float = ob.position.z
		ob.position.z += dz
		if ob.position.z > DESPAWN_Z:
			ob.deactivate()
			continue
		if check_collisions and prev_z < PLAYER_Z and ob.position.z >= PLAYER_Z:
			ob.counted = true
			if _hits_obstacle(ob, ship_xy):
				_crash()
				return
			_check_near_miss(ob, ship_xy)
	for g in _gates:
		if not g.active:
			continue
		var prev_z: float = g.position.z
		g.position.z += dz
		g.update_gate(delta, _time)
		if g.position.z > DESPAWN_Z:
			g.deactivate()
			continue
		if check_collisions and prev_z < PLAYER_Z and g.position.z >= PLAYER_Z:
			g.counted = true
			var d := ship_xy.distance_to(g.center)
			if d < GATE_HIT_RADIUS:
				_gate_hit(g)
			else:
				combo = 0
				combo_mult = 1
				_hud.set_combo(0, 1)

func _hits_obstacle(ob, ship_xy: Vector2) -> bool:
	for i in ob.centers.size():
		var c: Vector2 = ob.centers[i]
		var h: Vector2 = ob.halfs[i]
		if absf(ship_xy.x - c.x) < h.x + HIT_RADIUS and absf(ship_xy.y - c.y) < h.y + HIT_RADIUS:
			return true
	return false

func _check_near_miss(ob, ship_xy: Vector2) -> void:
	var best := 999.0
	for i in ob.centers.size():
		var c: Vector2 = ob.centers[i]
		var h: Vector2 = ob.halfs[i]
		var dx := maxf(absf(ship_xy.x - c.x) - h.x, 0.0)
		var dy := maxf(absf(ship_xy.y - c.y) - h.y, 0.0)
		best = minf(best, sqrt(dx * dx + dy * dy))
	if best < NEAR_MISS_DIST:
		score += 50.0
		_hud.show_popup("NEAR MISS +50")
		_audio.play_whoosh()
		_shake = maxf(_shake, 0.3)
		_fov_punch = 4.0

func _gate_hit(g) -> void:
	combo += 1
	combo_mult = clampi(combo, 1, 8)
	var points := 100 * combo_mult
	score += float(points)
	_speed_boost = minf(_speed_boost + 2.0, 6.0)
	_hud.set_combo(combo, combo_mult)
	_hud.show_popup("RING +%d" % points)
	_audio.play_chime(combo)
	_gate_burst.position = Vector3(g.center.x, g.center.y, PLAYER_Z)
	_gate_burst.restart()
	_shake = maxf(_shake, 0.12)

# ---------------------------------------------------------------- persistence + debug

func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_score = int(cfg.get_value("scores", "best", 0))

func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "best", best_score)
	cfg.save(SAVE_PATH)

func _state_name() -> String:
	match state:
		State.MENU:
			return "menu"
		State.PLAYING:
			return "playing"
		State.PAUSED:
			return "paused"
		State.GAMEOVER:
			return "gameover"
	return "unknown"

func _update_debug_hook() -> void:
	if OS.has_feature("web"):
		var s := "window.__ND=window.__ND||{};window.__ND.state='%s';window.__ND.score=%d;window.__ND.best=%d;window.__ND.speed=%.1f;window.__ND.fps=%d;window.__ND.combo=%d;window.__ND.music=%d;window.__ND.playing=%d;" % [_state_name(), int(score), best_score, speed, Engine.get_frames_per_second(), combo, 1 if _audio.music_ready else 0, 1 if _audio.music_player.playing else 0]
		JavaScriptBridge.eval(s)
