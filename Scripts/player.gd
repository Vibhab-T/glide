extends CharacterBody3D

enum PlayerState {WALKING, GLIDING}
var curr_player_state : PlayerState = PlayerState.WALKING

@export_group("Camera")
@export_range(0.0, 1.0) var sensitivity : float = 0.25
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

@export_group("Movement")
@export var move_speed: float = 15.0
@export var acceleration: float = 20.0
@export var rotation_speed: float = 12.0
@export var jump_force: float = 18.0
@export var gravity: float = -30.0 

@export_group("Gliding")
@export var sink_rate: float = 4.0
@export var glide_min_speed: float = 12.0
@export var glide_max_speed: float = 30.0
@export var glide_min_sink: float = -2
@export var glide_max_sink: float = 14.0
@export var glide_pitch_speed: float = 2.0
@export var glide_max_tilt_deg: float = 50.0 #nose up down tilt range



@onready var animation_player: AnimationPlayer = $characterMedium/AnimationPlayer
@onready var character: Node3D = $characterMedium

var _camera_input_dir : Vector2 = Vector2.ZERO
var _last_move_dir: Vector3 = Vector3.ZERO
var _last_walk_vel: Vector3 = Vector3.ZERO
var _glide_pitch : float = 0.0 #-1 fully up, 1, fully down



func walking_movement(delta: float) -> void:
	_camera_pivot.rotation.x += _camera_input_dir.y * delta
	_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, -PI/6, PI/3)
	_camera_pivot.rotation.y -= _camera_input_dir.x * delta
	_camera_input_dir = Vector2.ZERO
	
	var raw_input: Vector2 = Input.get_vector("left", "right", "forward", "backward")
	var forward := _camera.global_basis.z
	var right := _camera.global_basis.x
	
	var move_direction :Vector3 = forward * raw_input.y + right * raw_input.x
	move_direction.y = 0.0
	move_direction = move_direction.normalized()
	
	var y_vel := velocity.y
	velocity.y = 0.0
	velocity = velocity.move_toward(move_direction * move_speed, acceleration * delta)
	velocity.y = y_vel + gravity * delta
	
	var is_starting_jump : bool = Input.is_action_just_pressed("jump") and is_on_floor()
	if is_starting_jump:
		velocity.y += jump_force
	
	move_and_slide()
	
	if move_direction.length() > 0.2:
		_last_move_dir = move_direction
	var target_angle := Vector3.BACK.signed_angle_to(_last_move_dir, Vector3.UP)
	character.global_rotation.y = lerp_angle(character.rotation.y, target_angle, rotation_speed * delta)
	
	_last_walk_vel = velocity

func walking_animation()-> void:
	character.rotation.x = 0
	if (velocity.y != 0):
		animation_player.play("jump/Root|Jump")
		return
		
	if (velocity.length() > 0.0):
		animation_player.play("run/Root|Run")
		return
	
	animation_player.play("idle/Root|Idle")

func glide_animation() -> void:
	character.rotation.x = deg_to_rad(90.0) + deg_to_rad(_glide_pitch * glide_max_tilt_deg)
	animation_player.play("idle/Root|0_Targeting Pose")

func glide_movement(delta: float) -> void:
	_camera_pivot.rotation.x += _camera_input_dir.y * delta
	_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, -PI/6, PI/3)
	_camera_pivot.rotation.y -= _camera_input_dir.x * delta
	_camera_input_dir = Vector2.ZERO

	
	#pitch input
	var pitch_input := Input.get_axis("up", "down")
	_glide_pitch = move_toward(_glide_pitch, pitch_input, glide_pitch_speed * delta)
	
	#from -1 to 1 pitch to speed
	var t: float = (_glide_pitch + 1.0) / 2.0
	var target_speed: float = lerp(glide_min_speed, glide_max_speed, t)
	var target_sink: float = lerp(glide_min_sink, glide_max_sink, t)
	
	#cam relative input
	var raw_in : Vector2 = Input.get_vector("left", "right", "forward", "backward")
	var forward:= _camera.global_basis.z
	var right:= _camera.global_basis.x
	var move_dir : Vector3 = forward * raw_in.y + right * raw_in.x
	move_dir.y = 0.0
	if move_dir.length() > 0.01:
		move_dir = move_dir.normalized()
	else:
		move_dir = -_camera.global_basis.z
		move_dir.y = 0.0
		move_dir = move_dir.normalized()
	
	var horizontal_vel : Vector3 = move_dir * target_speed
	velocity.x = horizontal_vel.x
	velocity.z = horizontal_vel.z
	velocity.y = -target_sink
	
	if move_dir.length() > 0.2:
		_last_move_dir = move_dir

	var target_angle := Vector3.BACK.signed_angle_to(_last_move_dir, Vector3.UP)
	character.global_rotation.y = lerp_angle(character.rotation.y, target_angle, rotation_speed * delta)
	
	move_and_slide()

func glide_check() -> void:
	if is_on_floor():
		character.rotation.x = 0
		curr_player_state = PlayerState.WALKING


func _physics_process(delta: float) -> void:
	match curr_player_state:
		PlayerState.WALKING:
			walking_movement(delta)
			walking_animation()
		PlayerState.GLIDING:
			glide_check()
			glide_movement(delta)
			glide_animation()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if curr_player_state == PlayerState.WALKING and not is_on_floor():
			curr_player_state = PlayerState.GLIDING
	
	var is_camera_motion : bool = (
		event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)
	if is_camera_motion:
		_camera_input_dir = event.screen_relative * sensitivity 
