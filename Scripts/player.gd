extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@onready var animation_player: AnimationPlayer = $characterMedium/AnimationPlayer
@onready var character: Node3D = $characterMedium

var is_gliding: bool = false

func player_movement(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func player_animation() -> void:
	if (velocity.x != 0 or velocity.z != 0):
		animation_player.play("run/Root|Run")
		return
	
	if (velocity.y != 0):
		animation_player.play("jump/Root|Jump")
		return
	
	animation_player.play("idle/Root|Idle")

func player_glide() -> void:
	if is_on_floor():
		character.rotation.x = 0
		is_gliding = false
		return
	
	#set model
	character.rotation.x = 90
	

func _physics_process(delta: float) -> void:
	player_movement(delta)
	player_animation()
	if is_gliding : player_glide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		is_gliding = true
