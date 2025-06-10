extends CharacterBody2D

# Movement Parameters
@export var max_speed := 300.0
@export var acceleration := 1500.0
@export var friction := 1200.0
@export var air_resistance := 600.0
@export var jump_velocity := -500.0
@export var double_jump_velocity := -550.0
@export var wall_jump_velocity := Vector2(280, -525)
@export var gravity := 1700.0
@export var coyote_time := 0.2
@export var jump_buffer_time := 0.1
@export var idle2_chance := 0.5
@export var wall_bounce_multiplier := 1.5  
@export var min_bounce_velocity := 200.0
@export var max_bounce_velocity := 400.0
@export var wall_jump_combo_window := 0.15
@export var min_slam_velocity := -600.0
@export var max_slam_velocity := -1200.0
@export var max_slam_charge_time := 0.8

@export var dash_speed := 600.0
@export var dash_duration := 0.2
@export var dash_cooldown := 0.95
@export var dash_stop_gravity := true
@export var wall_slide_gravity := 300.0
@export var slam_velocity := 1000.0

# State System
enum State {
	IDLE,
	WALKING,
	JUMPING,
	DOUBLE_JUMPING,
	FALLING,
	WALL_SLIDING,
	DASHING,
	WALL_JUMPING,
	SLAMMING
}

var current_state: State = State.IDLE
var previous_state: State = State.IDLE

# Movement State
var slam_charge_timer := 0.0
var slam_start_height := 0.0
var has_double_jump := true
var wall_jump_combo_timer := 0.0
var should_slam_jump := false
var slam_jump_velocity := -650.0
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var wall_normal := Vector2.ZERO
var current_idle_anim := "Idle"
var dash_timer := 0.0
var can_dash := true
var dash_direction := Vector2.RIGHT
var jumped := false
var is_ground_slamming := false
var fall_timer := 0.0
var fall_start_height := 0.0
var is_charging_slam := false

@onready var sprite := $AnimatedSprite2D
@onready var normal_collision := $CollisionShape2D
@onready var dash_collision := $CollisionShape2D2

func _physics_process(delta: float) -> void:
	update_timers(delta)
	handle_state_transitions()
	handle_input()
	
	var _pre_move_velocity = velocity
	
	handle_movement(delta)
	move_and_slide()
	if current_state == State.DASHING and is_on_wall():
		wall_normal = get_wall_normal()
		var impact_angle = abs(wall_normal.dot(dash_direction))
		
		if impact_angle > 0.7:  # ~45 degree angle or more
			end_dash_abruptly()
			return
	apply_gravity(delta)
	update_animations()
	
	if is_charging_slam:
		slam_charge_timer += delta
	if is_charging_slam and slam_charge_timer >= max_slam_charge_time:
		end_ground_slam()

func is_facing_into_wall() -> bool:
	if not is_on_wall():
		return false
	wall_normal = get_wall_normal()
	var facing_dir := -1.0 if sprite.flip_h else 1.0
	return sign(wall_normal.x) == sign(facing_dir) and abs(wall_normal.x) > 0.7

func end_dash_abruptly() -> void:
	wall_normal = get_wall_normal()
	var bounce_power = clamp(abs(wall_normal.dot(dash_direction)) * dash_speed * wall_bounce_multiplier, min_bounce_velocity, max_bounce_velocity)
	
	velocity = wall_normal * bounce_power
	velocity.y *= 0.7  
	
	normal_collision.disabled = false
	dash_collision.disabled = true
	dash_timer = 0
	can_dash = false
	
	wall_jump_combo_timer = wall_jump_combo_window
	
	change_state(State.WALL_SLIDING if is_on_wall() and Input.get_axis("move_left", "move_right") != 0 else State.FALLING)
	
	if Input.is_action_pressed("jump"):
		velocity += Vector2(wall_normal.x * 300, -400)
	
	has_double_jump = true

func update_timers(delta: float) -> void:
	coyote_timer -= delta
	jump_buffer_timer -= delta
	dash_timer -= delta
	wall_jump_combo_timer -= delta
	
	if not can_dash and dash_timer <= -dash_cooldown:
		can_dash = true

func apply_gravity(delta: float) -> void:
	match current_state:
		State.DASHING:
			if dash_stop_gravity:
				velocity.y = 0
		State.WALL_SLIDING:
			velocity.y = min(velocity.y + wall_slide_gravity * delta, wall_slide_gravity)
		State.SLAMMING:
			velocity.y = slam_velocity
		_:
			if not is_on_floor():
				velocity.y += gravity * delta

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
				end_dash()
				change_state(State.FALLING if not is_on_floor() else State.IDLE)
		
		State.WALL_JUMPING:
			if velocity.y >= 0:
				change_state(State.FALLING)
			wall_jump_combo_timer = 0
		
		State.SLAMMING:
			if is_on_floor():
				end_ground_slam()

func handle_input() -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
		handle_jump()
	
	if Input.is_action_just_pressed("dash") and can_dash:
		if can_dash and not is_facing_into_wall():  # Explicit check
			handle_dash()
	
	if Input.is_action_just_pressed("slam") and can_slam():
		start_ground_slam()
	elif Input.is_action_just_released("slam") and is_ground_slamming:
		end_ground_slam()
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		jumped = true
	if Input.is_action_just_released("jump") and jumped:
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
		
		State.SLAMMING:
			velocity.y = slam_velocity
			velocity.x = 0
		
		State.WALKING, State.FALLING:
			if previous_state == State.DASHING:
				velocity.x = move_toward(velocity.x, 0, friction * delta)

func handle_jump() -> void:
	if current_state == State.WALL_SLIDING:
		perform_wall_jump()
	elif should_slam_jump:
		perform_slam_jump()
	elif (is_on_floor() or coyote_timer > 0) and current_state != State.DASHING:
		perform_regular_jump()
	elif has_double_jump and current_state not in [State.DASHING, State.SLAMMING]:
		if wall_jump_combo_timer > 0 and is_on_wall():
			perform_wall_jump_combo()
		else:
			perform_double_jump()

func perform_regular_jump() -> void:
	velocity.y = jump_velocity
	jump_buffer_timer = 0
	coyote_timer = 0
	change_state(State.JUMPING)

func perform_wall_jump_combo() -> void:
	velocity = Vector2(wall_normal.x * wall_jump_velocity.x * 1.2, wall_jump_velocity.y * 0.9) 
	jump_buffer_timer = 0
	wall_jump_combo_timer = 0 
	has_double_jump = false
	change_state(State.WALL_JUMPING)

func perform_wall_jump() -> void:
	wall_normal = get_wall_normal()  # Use class variable
	velocity = Vector2(wall_normal.x * wall_jump_velocity.x, wall_jump_velocity.y)
	jump_buffer_timer = 0
	has_double_jump = true
	change_state(State.WALL_JUMPING)

func perform_double_jump() -> void:
	wall_normal = get_wall_normal()
	velocity.y = double_jump_velocity
	has_double_jump = false
	jump_buffer_timer = 0
	change_state(State.DOUBLE_JUMPING)

func perform_slam_jump() -> void:
	var current_height_diff = slam_start_height - global_position.y
	
	if current_height_diff <= 0:
		velocity.y = slam_jump_velocity
	else:
		
		var required_velocity = calculate_min_jump_velocity(current_height_diff + 50)
		
		velocity.y = min(slam_jump_velocity, required_velocity)
	jump_buffer_timer = 0
	should_slam_jump = false
	has_double_jump = true
	change_state(State.JUMPING)

func handle_dash() -> void:
	var input_dir = Input.get_axis("move_left", "move_right")
	var dash_x = input_dir if input_dir != 0 else (-1.0 if sprite.flip_h else 1.0)
	dash_direction = Vector2(dash_x, 0).normalized()
	if is_on_wall() and sign(dash_direction.x) == sign(get_wall_normal().x):
		return
		
	dash_timer = dash_duration
	can_dash = false
	change_state(State.DASHING)
	normal_collision.disabled = true
	dash_collision.disabled = false
	velocity = dash_direction * dash_speed
	if dash_stop_gravity:
		velocity.y = 0

func end_dash() -> void:
	dash_timer = 0
	normal_collision.disabled = false
	dash_collision.disabled = true
	velocity.x = velocity.x * 0.7

func start_ground_slam() -> void:
	if is_on_floor():
		is_ground_slamming = false
		is_charging_slam = false
		
		var charge_ratio = min(slam_charge_timer / max_slam_charge_time, 1.0)
		var base_jump_velocity = lerp(min_slam_velocity, max_slam_velocity, charge_ratio)
		
		var height_diff = slam_start_height - global_position.y
		var min_required_velocity = sqrt(2 * gravity * (height_diff + 50))  # +50px buffer
		
		slam_jump_velocity = min(base_jump_velocity, -min_required_velocity)
		
		slam_jump_velocity = max(slam_velocity, max_slam_velocity)
		
		should_slam_jump = true
	slam_start_height = global_position.y
	change_state(State.SLAMMING)
	is_ground_slamming = true
	is_charging_slam = true
	slam_charge_timer = 0.0
	velocity.y = slam_velocity
	velocity.x = 0

func end_ground_slam() -> void:
	if is_on_floor():
		is_ground_slamming = false
		is_charging_slam = false
		should_slam_jump = true
		
		var charge_ratio = min(slam_charge_timer / max_slam_charge_time, 1.0)
		slam_jump_velocity = lerp(min_slam_velocity, max_slam_velocity, charge_ratio)

func calculate_min_jump_velocity(desired_height: float) -> float:
	return -sqrt(2 * gravity * desired_height)

func can_slam() -> bool:
	return not is_on_floor() and current_state not in [State.DASHING, State.WALL_SLIDING, State.SLAMMING]

func change_state(new_state: State) -> void:
	if new_state == State.FALLING and current_state != State.FALLING:
		fall_timer = 0.0
		fall_start_height = global_position.y
	if current_state == State.FALLING and new_state != State.FALLING:
		fall_timer = 0.0
	
	previous_state = current_state
	current_state = new_state
	
	match new_state:
		State.IDLE:
			sprite.play(current_idle_anim)
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
		
		State.SLAMMING:
			sprite.play("Slam")

func update_animations() -> void:
	if current_state == State.IDLE and abs(velocity.x) < 10:
		if sprite.animation not in ["Idle", "Idle2"]:
			current_idle_anim = "Idle2" if randf() < idle2_chance else "Idle"
		sprite.play(current_idle_anim)
