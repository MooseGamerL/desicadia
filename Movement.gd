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


func handle_idle(delta: float) -> void:
	var input_x := Input.get_axis("move_left", "move_right")
	if abs(input_x) > 0.1:
		change_state(State.WALKING)
	elif Input.is_action_just_pressed("jump") and (is_on_floor() or coyote_timer > 0):
		change_state(State.JUMPING)
	
func handle_walking(delta: float) -> void:
	var input_x := Input.get_axis("move_left", "move_right")
	velocity.x = move_toward(velocity.x, input_x * max_speed, acceleration * delta)
	
	if abs(velocity.x) < 1.0:
		change_state(State.IDLE)
	elif Input.is_action_just_pressed("jump"):
		change_state(State.JUMPING)
	
	# Sprite direction
	if input_x != 0:
		sprite.flip_h = input_x < 0

func handle_jumping(delta: float) -> void:
	var input_x := Input.get_axis("move_left", "move_right")
	velocity.x = move_toward(velocity.x, input_x * max_speed, air_resistance * delta)
	
	if velocity.y >= 0:
		change_state(State.FALLING)
	elif Input.is_action_just_pressed("jump") and has_double_jump:
		change_state(State.DOUBLE_JUMPING)

func handle_falling(delta: float) -> void:
	var input_x := Input.get_axis("move_left", "move_right")
	velocity.x = move_toward(velocity.x, input_x * max_speed, air_resistance * delta)
	
	if is_on_floor():
		change_state(State.IDLE)
	elif is_on_wall_only() and input_x != 0 and sign(input_x) == sign(get_wall_normal().x):
		change_state(State.WALL_SLIDING)

func handle_wall_sliding(delta: float) -> void:
	velocity.y = min(velocity.y + wall_slide_gravity * delta, wall_slide_gravity)
	
	if Input.is_action_just_pressed("jump"):
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
	if Input.is_action_just_pressed("jump"):
		change_state(State.WALL_JUMPING)
	elif not is_on_wall():
		change_state(State.FALLING)

func handle_slamming(delta: float) -> void:
	if is_on_floor():
		change_state(State.IDLE)

func reset_dash():
	can_dash = true
	dash_timer = 0
	if current_state not in [State.WALL_SLIDING, State.WALL_JUMPING]:
		$CollisionShape2D.disabled = false
		$CollisionShape2D2.disabled = true

#State changing
func change_state(new_state: State):
	match current_state:
		State.DASHING:
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
			reset_dash()
			has_double_jump = true
			
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
			var input_x = Input.get_axis("move_left", "move_right")
			dash_direction = Vector2(
				input_x if input_x != 0 else (-1 if sprite.flip_h else 1),
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
			velocity = Vector2.ZERO
			
		State.STICK:
			sprite.play("Dash")
			velocity = Vector2.ZERO
			wall_normal = get_wall_normal()

func _physics_process(delta: float) -> void:
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
		
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") and current_state in [State.IDLE, State.WALKING]:
		gravity -= -800
	elif event.is_action_released("jump") and current_state == State.JUMPING:
		gravity += 800
	
	if event.is_action_just_pressed("dash") and can_dash:
		change_state(State.DASHING)
	
	if event.is_action_just_pressed("slam") and not is_on_floor():
		change_state(State.SLAMMING)
