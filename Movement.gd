extends CharacterBody2D

#Variables
enum State {
	IDLE,
	WALKING,
	JUMPING,
	DOUBLE_JUMPING,
	FALLING,
	WALL_SLIDING,
	DASHING,
	WALL_JUMPING,
	SLAMMING,
	STICK
}

@export var max_speed := 300.0
@export var acceleration := 1500.0
@export var friction := 1200.0
@export var air_resistance := 600.0
@export var jump_velocity := -500.0
@export var double_jump_velocity := -550.0
@export var wall_jump_velocity := Vector2(280, -525)
@export var gravity := 1700
@export var coyote_time := 0.2
@export var jump_buffer_time := 0.1

@export var dash_duration := 0.2
@export var dash_speed := 600
@export var dash_cooldown := 0.95
@export var dash_stop_gravity := true
@export var wall_slide_gravity := 300.0

var current_state: State = State.IDLE
var previous_state: State = State.IDLE
var has_double_jump := true
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var wall_normal := Vector2.ZERO
var current_idle_anim := "idle"

var can_dash := true
var dash_timer := 0.0
var dash_direction := Vector2.RIGHT

var jump_pressed := false
var dash_pressed := false
var slam_pressed := false
var movement_input := 0.0

#Nodes
@onready var sprite := $AnimatedSprite2D
@onready var collision_shape := $CollisionShape2D
@onready var dash_collision_shape := $CollisionShape2D2

func _process(delta):
	if Input.is_action_just_pressed("jump"):
		jump_pressed = true
		jump_buffer_timer = jump_buffer_time
	if Input.is_action_just_pressed("dash"):
		print("dash pressed");
		dash_pressed = true
	if Input.is_action_just_pressed("slam"):
		slam_pressed = true
		
	# Continuous movement input (updated every frame)
	movement_input = Input.get_axis("move_left", "move_right")

func handle_idle(delta: float) -> void:
	if abs(movement_input) > 0.1:
		change_state(State.WALKING)
	elif jump_pressed and (is_on_floor() or coyote_timer > 0):
		jump_pressed = false
		change_state(State.JUMPING)
	
func handle_walking(delta: float) -> void:
	 # Get movement direction (left/right/neutral)
	var target_speed = movement_input * max_speed
	
	# Apply acceleration or friction based on input
	if movement_input != 0:
		# Accelerate toward target speed
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
		
		# Face the movement direction
		sprite.flip_h = movement_input < 0
	else:
		# Apply friction when no input
		velocity.x = move_toward(velocity.x, 0, friction * delta)
	# State transitions
	if abs(velocity.x) < 1.0:
		print("Chaning to idle")
		change_state(State.IDLE)
	elif jump_pressed:
		print("jump pressed in walkings")
		jump_pressed = false
		change_state(State.JUMPING)
	elif dash_pressed:
		print("dashHandled in walking")
		dash_pressed = false
		change_state(State.DASHING)

func handle_jumping(delta: float) -> void:
	velocity.x = move_toward(velocity.x, movement_input * max_speed, air_resistance * delta)
	
	if velocity.y >= 0:
		change_state(State.FALLING)
	elif jump_pressed and has_double_jump:
		jump_pressed =false
		change_state(State.DOUBLE_JUMPING)

func handle_falling(delta: float) -> void:
	velocity.x = move_toward(velocity.x, movement_input * max_speed, air_resistance * delta)
	
	if is_on_floor():
		change_state(State.IDLE)
	elif is_on_wall_only() and movement_input != 0 and sign(movement_input) == sign(get_wall_normal().x):
		change_state(State.WALL_SLIDING)

func handle_wall_sliding(delta: float) -> void:
	velocity.y = min(velocity.y + wall_slide_gravity * delta, wall_slide_gravity)
	
	if jump_pressed:
		jump_pressed = false
		change_state(State.WALL_JUMPING)
	elif not is_on_wall_only():
		change_state(State.FALLING)
	
	# Face away from wall
	wall_normal = get_wall_normal()
	sprite.flip_h = wall_normal.x > 0

func handle_dashing(delta: float) -> void:
	dash_timer -= delta
	if dash_timer <= 0:
		change_state(State.FALLING if not is_on_floor() else State.IDLE)
	elif is_on_wall_only():
		change_state(State.STICK)

func handle_stick(delta: float) -> void:
	if jump_pressed:
		jump_pressed = false
		change_state(State.WALL_JUMPING)
	elif not is_on_wall():
		change_state(State.FALLING)

func handle_slamming(delta: float) -> void:
	if is_on_floor():
		change_state(State.IDLE)

func reset_dash():
	can_dash = true
	dash_timer = 0
	dash_pressed = false
	collision_shape.disabled = false
	dash_collision_shape.disabled = true

#State changing
func change_state(new_state: State):
	match current_state:
		State.DASHING, State.STICK:
			if new_state != State.STICK:
				reset_dash()
		
	previous_state = current_state
	current_state = new_state
		
		
	match new_state:
		State.IDLE:
			sprite.play("Idle")
			reset_dash()
			has_double_jump = true
			
		State.WALKING:
			sprite.play("Walk")

			
		State.JUMPING:
			sprite.play("Jump")
			velocity.y = jump_velocity
			coyote_timer = 0
			jump_buffer_timer = 0
			
		State.DOUBLE_JUMPING:
			sprite.play("jump")
			velocity.y = double_jump_velocity
			has_double_jump = false
			
		State.FALLING:
			sprite.play("Fall")
			
		State.WALL_SLIDING:
			sprite.play("WallSlide")
			wall_normal = get_wall_normal()
			
		State.DASHING:
			collision_shape.disabled = true
			dash_collision_shape.disabled = false
			sprite.play("Dash")
			dash_timer = dash_duration
			can_dash = false
			dash_direction = Vector2(
				movement_input if movement_input != 0 else (-1 if sprite.flip_h else 1),
				0
			).normalized()
			velocity = dash_direction * dash_speed
			if dash_stop_gravity:
				velocity.y = 0      
				
		State.WALL_JUMPING:
			sprite.play("Jump") 
			velocity = Vector2(wall_normal.x * wall_jump_velocity.x, wall_jump_velocity.y)
			has_double_jump = true
			
		State.SLAMMING:
			sprite.play("Slam")
			velocity.y = abs(gravity) * 2
			
		State.STICK:
			sprite.play("Dash")
			velocity = Vector2.ZERO
			wall_normal = get_wall_normal()

func _physics_process(delta: float) -> void:
	var want_jump = jump_pressed or jump_buffer_timer > 0
	var want_dash = dash_pressed and can_dash
	var want_slam = slam_pressed and not is_on_floor()
	
	#dash_pressed = false
	slam_pressed = false
	
	update_timers(delta)
	
	match current_state:
		State.IDLE:
			handle_idle(delta)
		State.WALKING:
			handle_walking(delta)
		State.JUMPING:
			handle_jumping(delta)
		State.FALLING:
			handle_falling(delta)
		State.WALL_SLIDING:
			handle_wall_sliding(delta)
		State.DASHING:
			handle_dashing(delta)
		State.STICK:
			handle_stick(delta)
		State.SLAMMING:
			handle_slamming(delta)
			
	if not is_on_floor() and current_state not in [State.DASHING, State.WALL_SLIDING, State.SLAMMING]:
		velocity.y += gravity * delta
		
	move_and_slide()
	
	update_state_transitions()
	
func update_timers(delta: float) -> void:
	coyote_timer -= delta
	jump_buffer_timer -= delta
	dash_timer -= delta
	
	if not can_dash and dash_timer <= dash_cooldown:
		reset_dash()
	
func update_state_transitions() -> void:
	if current_state == State.STICK and not is_on_wall():
		change_state(State.FALLING)
