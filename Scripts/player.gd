extends CharacterBody2D

# Movement Parameters
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

# Dash Parameters
@export var dash_speed := 600.0
@export var dash_duration := 0.2
@export var dash_cooldown := 0.95
@export var dash_cooldown2 := dash_cooldown
@export var dash_stop_gravity := true
@export var wall_slide_gravity := 300.0  # Reduced gravity when sliding on wall

# State
var has_double_jump := true
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var wall_normal := Vector2.ZERO
var was_on_wall := false
var current_idle_anim := "Idle"
var dash_timer := 0.0
var can_dash := true
var is_dashing := false
var dash_direction := Vector2.RIGHT
var is_wall_sliding := false
var dash_wall_stick := false  # New state for when we dash into a wall
var jumped := false
var vel : Vector2 = Vector2()

@onready var sprite := $AnimatedSprite2D

func _physics_process(delta):
	# Update timers
	coyote_timer -= delta
	jump_buffer_timer -= delta
	dash_timer -= delta
	
	# Reset dash when cooldown ends
	if dash_timer <= -dash_cooldown:
		can_dash = true
		dash_cooldown = dash_cooldown2
	
	if gravity >= 1700.1:
		gravity = 1700
	elif gravity <= 899.9:
		gravity = 899.9
	
	# Handle dash movement
	if is_dashing:
		velocity = dash_direction * dash_speed
		if dash_stop_gravity:
			velocity.y = 0
		
		# Check if we hit a wall during dash
		move_and_slide()
		if is_on_wall_only() and not dash_wall_stick:
			dash_wall_stick = true
			dash_timer = 0  # End dash immediately
			is_dashing = false
			velocity = Vector2.ZERO
			wall_normal = get_wall_normal()
			sprite.play("Dash")
		
		if dash_timer <= 0 and not dash_wall_stick:
			is_dashing = false
			$CollisionShape2D.disabled = false
			$CollisionShape2D2.disabled = true
			# Reset animation after dash ends
			if is_on_floor():
				sprite.play("Idle")
			else:
				sprite.play("Fall")
	
	# Handle wall sliding (including after dash into wall)
	var on_wall = is_on_wall_only() and not is_on_floor()
	if on_wall or dash_wall_stick:
		is_wall_sliding = true
		wall_normal = get_wall_normal() if on_wall else wall_normal
		was_on_wall = true
		
		# Apply reduced gravity when sliding
		velocity.y = min(velocity.y + wall_slide_gravity * delta, wall_slide_gravity)
		
		# Stick to wall if we dashed into it
		if dash_wall_stick:
			velocity = Vector2.ZERO
			sprite.play("Dash")
	else:
		is_wall_sliding = false
		dash_wall_stick = false
		was_on_wall = was_on_wall and not is_on_floor()
	
	# Normal physics when not dashing or wall sliding
	if not is_dashing and not is_wall_sliding and not dash_wall_stick:
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			has_double_jump = true
			coyote_timer = coyote_time
	
	# Jump input
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	
	# Jump handling (disabled during dash)
	if jump_buffer_timer > 0 and not is_dashing:
		if is_on_floor() or coyote_timer > 0:
			velocity.y = jump_velocity
			jump_buffer_timer = 0
			coyote_timer = 0
			sprite.play("Jump")
			dash_wall_stick = false
		elif (is_wall_sliding or dash_wall_stick) and (wall_normal != Vector2.ZERO or dash_wall_stick):  # Only allow wall jump if actually on wall
			var wall_norm = wall_normal if wall_normal != Vector2.ZERO else (-dash_direction if dash_wall_stick else Vector2.ZERO)
			velocity = Vector2(wall_norm.x * wall_jump_velocity.x, wall_jump_velocity.y)
			jump_buffer_timer = 0
			has_double_jump = true  # Reset double jump when wall jumping
			sprite.play("Jump")
			$CollisionShape2D.disabled = false
			$CollisionShape2D2.disabled = true
			dash_wall_stick = false
			is_wall_sliding = false  # Important: Clear wall sliding state after jump
		elif has_double_jump:
			velocity.y = double_jump_velocity
			has_double_jump = false
			jump_buffer_timer = 0
			sprite.play("Jump")
	
	#jump release height
	if Input.is_action_just_pressed("jump") and is_on_floor():
		jumped = true
		vel.y -= jump_velocity
		gravity -= 800
	if Input.is_action_just_released("jump") and jumped:
		jumped = false
		gravity += 900
	
	# Dash input (Shift)
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing:
		var input_dir = Input.get_axis("move_left", "move_right")
		dash_direction = Vector2(input_dir if input_dir != 0 else (-1 if sprite.flip_h else 1), 0)
		dash_timer = dash_duration
		can_dash = false
		is_dashing = true
		dash_wall_stick = false
		sprite.play("Dash")
	
		# Toggle hitboxes - disable normal one, enable dash one
		$CollisionShape2D.disabled = true
		$CollisionShape2D2.disabled = false
	
	# Normal movement when not dashing or wall sticking
	if not is_dashing and not dash_wall_stick:
		var direction = Input.get_axis("move_left", "move_right")
		var accel = acceleration if is_on_floor() else air_resistance
		if direction != 0:
			velocity.x = move_toward(velocity.x, direction * max_speed, accel * delta)
		else:
			var decel = friction if is_on_floor() else air_resistance
			velocity.x = move_toward(velocity.x, 0, decel * delta)
			
	if Input.is_action_just_pressed("slam") and is_on_floor() == false:
		velocity.y -= -1000
		jump_velocity -= 100
	if jump_velocity <= -601:
		jump_velocity == -500
	
	
	# Animations (when not dashing)
	if not is_dashing:
		if is_on_floor():
			if abs(velocity.x) < 10:
				if sprite.animation not in ["Idle", "Idle2"]:
					current_idle_anim = "Idle2" if randf() < idle2_chance else "Idle"
				sprite.play(current_idle_anim)
			else:
				sprite.play("Walk")
		elif dash_wall_stick:
			sprite.play("Dash")
		elif is_wall_sliding:
			sprite.play("WallSlide")
		else:
			sprite.play("Jump" if velocity.y < 0 else "Fall")
	
	# Sprite direction
	if not dash_wall_stick:  # Only change direction when not stuck to wall
		var facing_dir = Input.get_axis("move_left", "move_right")
		if facing_dir != 0:
			sprite.flip_h = facing_dir < 0
	elif wall_normal != Vector2.ZERO:  # Face away from wall when stuck
		sprite.flip_h = wall_normal.x > 0
	
	if not is_dashing:  # Only move when not dashing (dashing movement is handled earlier)
		move_and_slide()
