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
@export var idle2_chance := 0.5

@export var dash_duration := 0.2
@export var dash_speed := 600
@export var dash_cooldown := 0.95
@export var dash_stop_gravity := true
@export var wall_slide_gravity := 300.0
@export var slam_velocity := 2000.0

var current_state: State = State.IDLE
var previous_state: State = State.IDLE

var current_idle_anim := "Idle"
var normal_gravity = gravity
var current_gravity := gravity
var has_double_jump := true
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var wall_normal := Vector2.ZERO
var can_dash := true
var dash_timer := 0.0
var dash_direction := Vector2.RIGHT
var jumped := false
var is_ground_slamming := false

@onready var sprite := $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	update_timers(delta)
	handle_state_transitions()
	apply_gravity(delta)
	handle_input()
	handle_movement(delta)
	move_and_slide()
	update_animations()

func update_timers(delta: float) -> void:
	coyote_timer -= delta
	jump_buffer_timer -= delta
	dash_timer -= delta
	
	if not can_dash and dash_timer <= -dash_cooldown:
		can_dash = true

func apply_gravity(delta: float) -> void:
	match current_state:
		State.DASHING:
			if dash_stop_gravity:
				velocity.y = 0
		State.STICK:
			velocity.y = 0
		State.WALL_SLIDING:
			velocity.y = min(velocity.y + wall_slide_gravity * delta, wall_slide_gravity)
		State.SLAMMING:
			velocity.y = slam_velocity
		_:
			if not is_on_floor():
				velocity.y += current_gravity * delta
			else:
				velocity.y = 0

func handle_state_transitions() -> void:
	match current_state:
		State.IDLE:
			if not is_on_floor():
				change_state(State.FALLING)
			elif abs(velocity.x) > 10:
				change_state(State.WALKING)
		
		State.WALKING:
			if not is_on_floor():
				change_state(State.FALLING)
			elif abs(velocity.x) < 10:
				change_state(State.IDLE)
		
		State.JUMPING:
			if velocity.y >= 0:
				change_state(State.FALLING)
		
		State.DOUBLE_JUMPING:
			if velocity.y >= 0:
				change_state(State.FALLING)
		
		State.FALLING:
			if is_on_floor():
				change_state(State.IDLE)
			elif is_on_wall() and Input.get_axis("move_left", "move_right") != 0:
				change_state(State.WALL_SLIDING)
		
		State.WALL_SLIDING:
			if not is_on_wall():
				change_state(State.FALLING)
		
		State.DASHING:
			if dash_timer <= 0:
				change_state(State.FALLING if not is_on_floor() else State.IDLE)
			elif is_on_wall():
				change_state(State.STICK)
		
		State.WALL_JUMPING:
			if velocity.y >= 0:
				change_state(State.FALLING)
		
		State.STICK:
			if not is_on_wall():
				change_state(State.FALLING)
		
		State.SLAMMING:
			if is_on_floor():
				change_state(State.IDLE)

func handle_input() -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
		handle_jump()
	
	if Input.is_action_just_pressed("dash") and can_dash:
		handle_dash()
	
	if Input.is_action_just_pressed("slam") and can_slam():
		start_ground_slam()
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		jumped = true
	if Input.is_action_just_pressed("jump") and jumped:
		jumped = false
		if velocity.y < jump_velocity * 0.5:
			velocity.y = jump_velocity * 0.5

func handle_movement(delta: float) -> void:
	var direction = Input.get_axis("move_left", "move_right")
	
	match current_state:
		State.IDLE, State.WALKING:
			if direction != 0:
				velocity.x = move_toward(velocity.x, direction * max_speed, acceleration * delta)
				sprite.flip_h = direction < 0
			else:
				velocity.x = move_toward(velocity.x, 0, friction * delta)
		
		State.JUMPING, State.DOUBLE_JUMPING, State.FALLING, State.WALL_JUMPING:
			velocity.x = move_toward(velocity.x, direction * max_speed, air_resistance * delta)
			if direction != 0:
				sprite.flip_h = direction < 0
		
		State.WALL_SLIDING:
			wall_normal = get_wall_normal()
			sprite.flip_h = wall_normal.x > 0
		
		State.DASHING:
			velocity = dash_direction * dash_speed
			if dash_stop_gravity:
				velocity.y = 0
		
		State.STICK:
			velocity = Vector2.ZERO
		
		State.SLAMMING:
			velocity.y = slam_velocity
			velocity.x = 0

func handle_jump() -> void:
	if current_state  == State.WALL_SLIDING or current_state == State.STICK:
		perform_wall_jump()
	elif (is_on_floor() or coyote_timer > 0) and current_state != State.DASHING:
		perform_regular_jump()
	elif has_double_jump and current_state not in [State.DASHING, State.STICK, State.SLAMMING]:
		perform_double_jump()

func perform_regular_jump() -> void:
	velocity.y = jump_velocity
	jump_buffer_timer = 0
	coyote_timer = 0
	change_state(State.JUMPING)

func perform_wall_jump() -> void:
	velocity = Vector2(wall_normal.x * wall_jump_velocity.x, wall_jump_velocity.y)
	jump_buffer_timer = 0
	has_double_jump = true
	change_state(State.WALL_JUMPING)
	$CollisionShape2D.disabled = false

func perform_double_jump() -> void:
	velocity.y = double_jump_velocity
	has_double_jump = false
	jump_buffer_timer = 0
	change_state(State.DOUBLE_JUMPING)

func handle_dash() -> void:
	var input_dir = Input.get_axis("move_left", "move_right")
	var dash_x: float
	
	if input_dir != 0:
		dash_x = input_dir
	else:
		dash_x = 1.0 if sprite.flip_h else 1.0
	
	dash_direction = Vector2(dash_x, 0).normalized()
	dash_timer = dash_duration
	can_dash = false
	change_state(State.DASHING)
	$CollisionShape2D.disabled = true

func start_ground_slam() -> void:
	change_state(State.SLAMMING)
	gravity = normal_gravity * 1.5


func handle_dash_movement() -> void:
	velocity = dash_direction * dash_speed
	if dash_stop_gravity:
		velocity.y = 0

func handle_ground_movement(delta: float) -> void:
	var direction = Input.get_axis("move_left", "move_right")
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * max_speed, acceleration * delta)
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

func handle_air_movement(delta: float) -> void:
	var direction = Input.get_axis("move_left", "move_right")
	velocity.x = move_toward(velocity.x, direction * max_speed, air_resistance * delta)
	if direction != 0 and current_state not in [State.DASHING, State.WALL_JUMPING]:
		sprite.flip_h = direction < 0

func handle_wall_slide(delta: float) -> void:
	wall_normal = get_wall_normal()
	sprite.flip_h = wall_normal.x > 0
	velocity.y = min(velocity.y + wall_slide_gravity * delta, wall_slide_gravity)

func can_slam() -> bool:
	return (not is_on_floor() and 
	current_state not in [
		State.DASHING,
		State.WALL_SLIDING, 
		State.STICK, 
		State.SLAMMING
		])

func change_state(new_state: State) -> void:
	if current_state == State.SLAMMING and new_state != State.SLAMMING:
		gravity = normal_gravity
		is_ground_slamming = false
	
	previous_state = current_state
	current_state = new_state
	
	match new_state:
		State.IDLE:
			sprite.play("Idle")
			has_double_jump = true
			coyote_timer = coyote_time
		
		State.WALKING:
			sprite.play("Walk")
		
		State.JUMPING:
			sprite.play("Jump")
		
		State.DOUBLE_JUMPING:
			sprite.play("Jump")
		
		State.FALLING:
			sprite.play("Fall")
		
		State.WALL_SLIDING:
			sprite.play("WallSlide")
			wall_normal = get_wall_normal()
		
		State.DASHING:
			sprite.play("Dash")
		
		State.WALL_JUMPING:
			sprite.play("Jump")
		
		State.STICK:
			sprite.play("Dash")
			wall_normal = get_wall_normal()
		
		State.SLAMMING:
			sprite.play("Slam")
			is_ground_slamming = true

func update_animations() -> void:
	if current_state == State.IDLE and abs (velocity.x) < 10:
		if sprite.animation not in ["Idle", "Idle2"]:
			current_idle_anim = "idle2" if randf() < idle2_chance else "idle"
		sprite.play(current_idle_anim)
