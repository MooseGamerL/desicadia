#Player movement code.
extends CharacterBody2D

#Walk/Running variables
@export var max_speed := 300.0
@export var acceleration := 1500.0
@export var friction := 1200.0
@export var air_resistance := 600.0

#Jump variables
@export var jump_velocity := -500.0
@export var gravity := 1700.0
@export var coyote_time := 0.2
@export var jump_buffer_time := 0.1
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var wall_normal := Vector2.ZERO
var jumped := false

#Double-Jump variables
@export var double_jump_velocity := -550.0
var has_double_jump := true

#Wall-bounce/Wall-slide/Wall-jump variables
@export var wall_bounce_multiplier := 1.5  
@export var min_bounce_velocity := 200.0
@export var max_bounce_velocity := 400.0
@export var wall_jump_combo_window := 0.15
@export var wall_slide_gravity := 300.0
@export var wall_jump_velocity := Vector2(280, -525)
var wall_jump_combo_timer := 0.0
var current_wall_normal := Vector2.ZERO
var grace_timer := 0.0
const WALL_GRACE_TIME := 0.15

#Slam variables
@export var min_slam_velocity := -600.0
@export var max_slam_velocity := -1200.0
@export var max_slam_charge_time := 0.8
@export var slam_velocity := 1000.0
@export var slam_jump_window := 0.5
var slam_charge_timer := 0.0
var slam_start_height := 0.0
var should_slam_jump := false
var slam_jump_velocity := -650.0
var slam_jump_window_timer := 0.0
var slam_completion_timer := 0.0
var is_ground_slamming := false
var is_charging_slam := false
var fall_timer := 0.0
var fall_start_height := 0.0
const SLAM_COMPLETION_WINDOW := 0.3

#Dash variables
@export var dash_speed := 600.0
@export var dash_duration := 0.2
@export var dash_cooldown := 0.95
@export var dash_stop_gravity := true
var dash_timer := 0.0
var can_dash := true
var dash_direction := Vector2.RIGHT

#Health/Respawn variables.
@export var respawn_position: Vector2
@export var max_health := 3
var current_health: float

#Every state.
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

#State change variables.
var current_state: State = State.IDLE
var previous_state: State = State.IDLE

#Node variables.
@onready var sprite := $AnimatedSprite2D
@onready var normal_collision := $CollisionShape2D
@onready var dash_collision := $CollisionShape2D2
@onready var health_bar: ProgressBar

#This function uses the _ready() function, which gets things ready before the game starts. 
#It adds the player to the player group and sets its collision layer to 1 and collision mask to 1 and 2, meaning it can  interact with walls and enemies.
#It sets the players health to its maximum.
func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 1 | 2
	current_health = max_health
	update_health_bar()

#This take_damage function tells the player how much health to lose and to die.
func take_damage(ammount: float) -> void:
	current_health = max(current_health - ammount, 0.0)
	update_health_bar()
	if current_health <= 0:
		die()

#The update_health_bar() function tells the healthbar to change whenever the player takes damage.
func update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.queue_redraw()

#The die() function resets the player's health and position when they die.
func die() -> void:
	global_position = Vector2(450, 225)
	current_health = max_health
	update_health_bar()

#The get_health_percentage() function finds the percentage of how full the player's health is so it can display it on the healthbar.
func get_health_percentage() -> float:
	return current_health / max_health

#Assigns the progressbar to the healthbar and updates it immediatly.
func set_health_bar(bar: ProgressBar) -> void:
	health_bar = bar
	update_health_bar()

#Updates every physics frame to start a timer.
func _physics_process(delta: float) -> void:
	# Reset wall_normal if not on a wall
	if not is_on_wall() and grace_timer <= 0:
		wall_normal = Vector2.ZERO
	grace_timer = max(grace_timer - delta, 0.0)
	#If the player is touching a wall, it saves the wall's normal direction and resets the grace timer.
	if is_on_wall():
		current_wall_normal = get_wall_normal()
		grace_timer = WALL_GRACE_TIME
	#updates timers, transitions states, reads input, moves the character, checks for collisions, if the player is dashing into a wall at an angle it ends the dash immediately to simulate an impact or failed dash.
	update_timers(delta)
	handle_state_transitions()
	handle_input()
	var _pre_move_velocity = velocity
	handle_movement(delta)
	move_and_slide()
	check_enemy_collisions()
	if current_state == State.DASHING and is_on_wall():
		wall_normal = get_wall_normal()
		var impact_angle = abs(wall_normal.dot(dash_direction))
		if impact_angle > 0.7:  
			end_dash_abruptly()
			return
	#applies gravity and updates animations and if the player is charging slam it increases the slam charge timer.
	apply_gravity(delta)
	update_animations()
	if is_charging_slam:
		slam_charge_timer += delta
	if is_charging_slam and slam_charge_timer >= max_slam_charge_time:
		end_ground_slam()

#This is a function to test if the player is facing into a wall to wall jump.
func is_facing_into_wall() -> bool:
	if not is_on_wall():
		return false
	wall_normal = get_wall_normal()
	var facing_dir := -1.0 if sprite.flip_h else 1.0
	return sign(wall_normal.x) == sign(facing_dir) and abs(wall_normal.x) > 0.7

#This function instantly ends a dash if the player dashes into a wall, and bounces them back.
func end_dash_abruptly() -> void:
	wall_normal = get_wall_normal()
	var bounce_power = clamp(abs(wall_normal.dot(dash_direction)) * dash_speed * wall_bounce_multiplier, min_bounce_velocity, max_bounce_velocity)
	velocity = wall_normal * bounce_power
	velocity.y *= 0.7  # Slightly reduce vertical bounce
	# Keep wall detection active for immidate wall jumping
	grace_timer = WALL_GRACE_TIME
	wall_jump_combo_timer = 0.0
	# Reset collisions
	normal_collision.disabled = false
	dash_collision.disabled = true
	dash_timer = 0
	can_dash = false
	# Force FALLING state (no wall-sliding)
	change_state(State.FALLING)

#This function counds down timers for different abilities, and checks if some of the timers are over.
func update_timers(delta: float) -> void:
	coyote_timer -= delta
	jump_buffer_timer -= delta
	dash_timer -= delta
	wall_jump_combo_timer -= delta
	slam_completion_timer = max(slam_completion_timer - delta, 0.0)
	
	if slam_jump_window_timer > 0:
		slam_jump_window_timer -= delta
		if slam_jump_window_timer <= 0 and should_slam_jump:
			should_slam_jump = false
	if not can_dash and dash_timer <= -dash_cooldown:
		can_dash = true

#This function removes gravity if dashing, lowers gravity when wall sliding, and increases gravity when slamming. It also applies gravity when jumping or falling.
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

#This function switches the player's state based on movement conditions.
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
			elif is_on_wall():
				pass
		State.FALLING:
			if is_on_floor():
				change_state(State.IDLE)
			elif is_on_wall() and Input.get_axis("move_left", "move_right") != 0:
				change_state(State.WALL_SLIDING)  # Only slide if allowed
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

#Tells the game how to react when inputs corresponding to particular movements are pressed/released
func handle_input() -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
		handle_jump()
	if Input.is_action_just_pressed("dash") and can_dash:
		if can_dash and not is_facing_into_wall():
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

#This function updates the character's velocity and sprite direction based on input and current state
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

#This function determines which type of jump to execute. Slam jump, wall jump, regular jump, wall jump combo, or double jump.
func handle_jump() -> void:
	if should_slam_jump and slam_jump_window_timer > 0:
		perform_slam_jump()
	elif can_wall_jump():
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var platform = collision.get_collider()
			if platform.is_in_group("moving_platform") and platform.has_method("get_wall_jump_normal"):
				var platform_wall_normal = platform.get_wall_jump_normal()  # Unique name
				if platform_wall_normal != Vector2.ZERO:
					velocity = Vector2(platform_wall_normal.x * wall_jump_velocity.x, wall_jump_velocity.y)
					jump_buffer_timer = 0
					change_state(State.WALL_JUMPING)
					return
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

#This function initiates a standard jump by setting upward velocity, resetting jump-related timers, and switching the state to JUMPING.
func perform_regular_jump() -> void:
	velocity.y = jump_velocity
	wall_jump_combo_timer = 0.0
	jump_buffer_timer = 0
	coyote_timer = 0
	change_state(State.JUMPING)

#This function performs a boosted wall jump by applying a modified velocity away from the wall, resetting timers, disabling double jump, and changing the state to WALL_JUMPING.
func perform_wall_jump_combo() -> void:
	velocity = Vector2(wall_normal.x * wall_jump_velocity.x * 1.2, wall_jump_velocity.y * 0.9) 
	jump_buffer_timer = 0
	wall_jump_combo_timer = 0 
	has_double_jump = false
	change_state(State.WALL_JUMPING)
#This function allows the player to jump off a wall, resets the jump buffer timer, enables double jump, and sets the state to jumping
func perform_wall_jump() -> void:
	if not is_on_wall() and grace_timer <= 0:
		return
	velocity = Vector2(wall_normal.x * wall_jump_velocity.x, wall_jump_velocity.y)
	jump_buffer_timer = 0
	has_double_jump = true
	change_state(State.WALL_JUMPING)
	# Reset timers to prevent bleed into next jumps
	wall_jump_combo_timer = wall_jump_combo_window

#This function allows the player to jump once while midair, and changes the state to double jumping.
func perform_double_jump() -> void:
	if is_on_wall() or wall_jump_combo_timer > 0:
		return
	velocity.y = double_jump_velocity
	wall_jump_combo_timer = 0.0
	has_double_jump = false
	jump_buffer_timer = 0
	change_state(State.DOUBLE_JUMPING)

#This function executes a powerful upward jump after a slam if conditions are met, resetting flags and timers, enabling double jump, and switching to JUMPING. Otherwise, it defaults to a regular jump if grounded and buffered.
func perform_slam_jump() -> void:
	if should_slam_jump and slam_jump_window_timer > 0:
		velocity.y = slam_jump_velocity
		jump_buffer_timer = 0
		should_slam_jump = false
		slam_jump_window_timer = 0
		has_double_jump = true
		change_state(State.JUMPING)
	else:
		if is_on_floor() and jump_buffer_timer > 0:
			perform_regular_jump()

#This function enables the dash, cancels it if dashing into a wall and switches to the dashing state.
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

#This function ends the dash, while keeping momentum.
func end_dash() -> void:
	dash_timer = 0
	normal_collision.disabled = false
	dash_collision.disabled = true
	velocity.x = velocity.x * 0.7

#This function function begins a slam by setting downward velocity, charging flags, and state, and if on the ground, calculates a follow-up jump velocity based on charge and height.
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

#this function ends the slam when grounded by resetting flags, opening the slam jump window, and switching to the IDLE state.
func end_ground_slam() -> void:
	if is_on_floor():
		is_ground_slamming = false
		is_charging_slam = false
		slam_completion_timer = SLAM_COMPLETION_WINDOW
		should_slam_jump = true
		slam_jump_window_timer = slam_jump_window
		change_state(State.IDLE)

		var charge_ratio = min(slam_charge_timer / max_slam_charge_time, 1.0)
		slam_jump_velocity = lerp(min_slam_velocity, max_slam_velocity, charge_ratio)

#This function returns the minimum upward velocity needed to reach a given jump height based on gravity.
func calculate_min_jump_velocity(desired_height: float) -> float:
	return -sqrt(2 * gravity * desired_height)

#This function checks if the player meets the conditions to slam.
func can_slam() -> bool:
	return not is_on_floor() and current_state not in [State.DASHING, State.WALL_SLIDING, State.SLAMMING]

#This function checks if the player meets the conditions to wall jump.
func can_wall_jump() -> bool:
	if current_state == State.DASHING:
		return false
	var input_dir = Input.get_axis("move_left", "move_right")
	var pushing_into_wall = (input_dir < 0 and wall_normal.x > 0) or (input_dir > 0 and wall_normal.x < 0)
	return (is_on_wall() or grace_timer > 0) and pushing_into_wall

#This function updates your current and previous state, resets fall timers as needed, adjusts double jump and coyote timers, and plays the corresponding animation for the new state.
func change_state(new_state: State) -> void:
	# Don't clear wall normal when transitioning from DASHING to FALLING (For wall jump after dash)
	if current_state == State.DASHING and new_state == State.FALLING:
		#Keep wall normal and grace timer for immediate wall jumping
		pass
	elif current_state in [State.WALL_SLIDING, State.WALL_JUMPING]:
		if new_state not in [State.WALL_SLIDING, State.WALL_JUMPING]:
			wall_normal = Vector2.ZERO
			wall_jump_combo_timer = 0.0
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
		State.SLAMMING:
			sprite.play("Slam")

#This function plays the idle animation when the character is idle and barely moving horizontally.
func update_animations() -> void:
	if current_state == State.IDLE and abs(velocity.x) < 10:
		sprite.play("Idle")

#Tells the game when the player can no longer slam jump.
func was_recently_slamming() -> bool:
	return slam_completion_timer > 0.0

#This function tells the game  if the player is attacking by dashing or slamming.
func is_player_attacking() -> bool:
	if current_state == State.DASHING:
		return true
	if current_state == State.SLAMMING:
		return true
	if was_recently_slamming():
		return true
	return false

#This function checks if the player is touching an enemy, and if the player is attacking, the enemy dies.
func check_enemy_collisions():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("enemy"):
			if is_player_attacking():
				if collider.has_method("die"):
					collider.die()
				return
