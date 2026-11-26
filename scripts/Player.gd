extends CharacterBody3D
class_name PlayerController

const SPEED := 7.0
const ACCEL := 48.0
const TURN_ACCEL := 78.0
const DECEL := 38.0
const AIR_ACCEL := 28.0

const JUMP_VELOCITY := 7.15
const GRAVITY_UP := 15.2
const GRAVITY_DOWN := 29.5
const APEX_BAND := 1.15
const APEX_GRAVITY_MULT := 0.56
const MAX_FALL_SPEED := 22.0

const COYOTE_MAX := 0.10
const BUFFER_MAX := 0.14

var role: String = "boy"
var model: Chibi3D
var col_shape: CollisionShape3D
var can_move: bool = true
var seated_mode: bool = false
var dust_timer: float = 0.0
var attack_cd: float = 0.0

var coyote_timer: float = 0.0
var jump_buffer: float = 0.0
var attack_buffer: float = 0.0
var was_on_floor: bool = true
var prev_vy: float = 0.0
var _anim_scale := Vector3.ONE
var _anim_scale_vel := Vector3.ZERO

signal moved_step(pos: Vector3)
signal landed(pos: Vector3, impact: float)
signal attacked(pos: Vector3, forward: Vector3)


func setup(p_role: String) -> void:
	role = p_role
	model = Chibi3D.create(role)
	model.scale = Vector3.ONE * 0.92
	add_child(model)

	# Warm golden-amber lantern key light (contrasts against cool twilight forest shadows)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.56)
	light.light_energy = 0.88
	light.omni_range = 7.2
	light.omni_attenuation = 1.35
	light.position = Vector3(0, 1.75, 0.25)
	add_child(light)


func set_seated_mode(seated: bool) -> void:
	seated_mode = seated
	can_move = not seated
	velocity = Vector3.ZERO
	jump_buffer = 0.0
	attack_buffer = 0.0
	_anim_scale = Vector3.ONE
	if col_shape:
		col_shape.disabled = seated
	if model:
		model.scale = Vector3.ONE * 0.92
		model.set_sitting(seated)


func trigger_squash(target_sc: Vector3) -> void:
	_anim_scale = target_sc
	_anim_scale_vel = Vector3.ZERO


func _ready() -> void:
	col_shape = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.40
	shape.height = 1.6
	col_shape.shape = shape
	col_shape.position = Vector3(0, 0.8, 0)
	add_child(col_shape)


func _input(event: InputEvent) -> void:
	if seated_mode or not can_move:
		return
	if event.is_action_pressed("jump"):
		jump_buffer = BUFFER_MAX
	elif event.is_action_pressed("attack"):
		attack_buffer = BUFFER_MAX


func _physics_process(delta: float) -> void:
	var real_dt := minf(delta / maxf(Engine.time_scale, 0.001), 0.05)

	if seated_mode:
		if model:
			model.scale = Vector3.ONE * 0.92
			model.update_anim(false, false, delta)
		return

	# Decay input buffers & cooldowns in unscaled real time so inputs during hitstop always register!
	if jump_buffer > 0.0:
		jump_buffer = maxf(0.0, jump_buffer - real_dt)
	if attack_buffer > 0.0:
		attack_buffer = maxf(0.0, attack_buffer - real_dt)
	if attack_cd > 0.0:
		attack_cd = maxf(0.0, attack_cd - real_dt)

	var on_ground := is_on_floor()
	if on_ground:
		coyote_timer = COYOTE_MAX
	else:
		coyote_timer = maxf(0.0, coyote_timer - real_dt)

	# Asymmetric jump curve: light rising gravity, brief apex hang, heavy crisp falling gravity!
	if not on_ground:
		var grav := GRAVITY_DOWN
		if velocity.y > 0.0:
			if absf(velocity.y) < APEX_BAND:
				grav = GRAVITY_UP * APEX_GRAVITY_MULT
			else:
				grav = GRAVITY_UP
			# Variable short-hop cut if player releases jump button early
			if not Input.is_action_pressed("jump"):
				grav *= 1.85
		elif absf(velocity.y) < APEX_BAND:
			grav = GRAVITY_DOWN * 0.68
		velocity.y = maxf(-MAX_FALL_SPEED, velocity.y - grav * delta)

	if not can_move:
		velocity.x = move_toward(velocity.x, 0.0, DECEL * delta)
		velocity.z = move_toward(velocity.z, 0.0, DECEL * delta)
		prev_vy = velocity.y
		move_and_slide()
		_update_squash_spring(real_dt)
		if model:
			model.update_anim(false, not is_on_floor(), delta)
		was_on_floor = is_on_floor()
		return

	# Buffered + Coyote Jump Execution
	if jump_buffer > 0.0 and coyote_timer > 0.0:
		jump_buffer = 0.0
		coyote_timer = 0.0
		velocity.y = JUMP_VELOCITY
		on_ground = false
		trigger_squash(Vector3(0.84, 1.22, 0.84))
		SoundFX.play("jump", -8.0)

	# Buffered Attack Execution
	if attack_buffer > 0.0 and attack_cd <= 0.0:
		attack_buffer = 0.0
		attack_cd = 0.28
		if model:
			model.trigger_attack()
			trigger_squash(Vector3(1.14, 0.90, 1.14))
			SoundFX.play("bonk", -7.0)
			var fwd := Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y)).normalized()
			attacked.emit(global_position, fwd)

	var ix := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var iz := Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	var dir := Vector3(ix, 0.0, iz)

	var walking := dir.length() > 0.05
	if walking:
		dir = dir.normalized()
		var target_vx := dir.x * SPEED
		var target_vz := dir.z * SPEED
		var cur_h := Vector2(velocity.x, velocity.z)
		var tgt_h := Vector2(target_vx, target_vz)
		var reversing := cur_h.length() > 0.5 and cur_h.normalized().dot(tgt_h.normalized()) < -0.15
		var acc := (TURN_ACCEL if reversing else ACCEL) if on_ground else AIR_ACCEL
		velocity.x = move_toward(velocity.x, target_vx, acc * delta)
		velocity.z = move_toward(velocity.z, target_vz, acc * delta)

		if model:
			var target_yaw := atan2(dir.x, dir.z)
			model.rotation.y = lerp_angle(model.rotation.y, target_yaw, minf(1.0, delta * 15.0))
			# Subtle forward lean proportional to speed
			var spd_ratio := clampf(Vector2(velocity.x, velocity.z).length() / SPEED, 0.0, 1.0)
			model.body_pivot.rotation.x = lerpf(model.body_pivot.rotation.x, 0.09 * spd_ratio, minf(1.0, delta * 12.0))

		if on_ground:
			dust_timer += delta
			if dust_timer >= 0.23:
				dust_timer = 0.0
				SoundFX.play("step", -19.5)
				moved_step.emit(global_position)
	else:
		# Smooth ease-out settle instead of abrupt robotic snap
		var dec := DECEL if on_ground else (AIR_ACCEL * 0.65)
		velocity.x = move_toward(velocity.x, 0.0, dec * delta)
		velocity.z = move_toward(velocity.z, 0.0, dec * delta)

	prev_vy = velocity.y
	move_and_slide()

	var now_floor := is_on_floor()
	if now_floor and not was_on_floor and prev_vy < -2.2:
		var impact := clampf(absf(prev_vy) / 14.0, 0.25, 1.0)
		trigger_squash(Vector3(1.0 + 0.22 * impact, 1.0 - 0.22 * impact, 1.0 + 0.22 * impact))
		SoundFX.play("land", -12.5)
		GameJuice.add_trauma(0.11 * impact)
		landed.emit(global_position, impact)
	was_on_floor = now_floor

	_update_squash_spring(real_dt)
	if model:
		model.update_anim(walking, not now_floor, delta)


func _update_squash_spring(dt: float) -> void:
	# Damped harmonic spring (overshoots slightly like EaseOutBack, always settles cleanly at ONE)
	var stiffness := 240.0
	var damping := 19.5
	var force := (Vector3.ONE - _anim_scale) * stiffness
	_anim_scale_vel = (_anim_scale_vel + force * dt) * exp(-damping * dt)
	_anim_scale += _anim_scale_vel * dt
	if (_anim_scale - Vector3.ONE).length() < 0.002 and _anim_scale_vel.length() < 0.01:
		_anim_scale = Vector3.ONE
		_anim_scale_vel = Vector3.ZERO
	if model:
		model.scale = _anim_scale * 0.92
