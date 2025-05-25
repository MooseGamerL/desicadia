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

#Nodes
@onready var sprite := $AnimatedSprite2D
@onready var collision_shape := $CollisionShape2D
@onready var dash_collision_shape := $CollisionShape2D2

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
		State.WALKING:
			has_double_jump = true
			reset_dash()
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
			sprite.play("WallSlide")
		State.WALL_SLIDING:
			sprite.play("WallSlide")
			wall_normal = get_wall_normal()
		State.DASHING:
			collision_shape.disabled = true
			dash_collision_shape.disabled = false
			sprite.play("Dash")
			dash_timer = dash_duration
			can_dash = false
			var input_dir = Input.get_axis("move_left", "move_right")
			dash_direction = Vector2(
				input_dir if input_dir != 0 else (-1 if sprite.flip_h else 1),
				0
			).normalized()
			velocity = dash_direction * dash_speed
			if dash_stop_gravity:
				velocity.y = 0      
		State.WALL_JUMPING:
			sprite.play("Jump") 
			velocity = wall_normal * Vector2(wall_jump_velocity.x, wall_jump_velocity.y)
			has_double_jump = true
		State.SLAMMING:
			sprite.play("Slam")
			velocity.y = abs(gravity) * 2
		State.STICK:
			sprite.play("Dash")
			velocity = Vector2.ZERO
			wall_normal = get_wall_normal()
			
	func _physics_process(delta):
		coyote_timer -= delta
