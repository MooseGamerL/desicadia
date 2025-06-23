extends CharacterBody2D

@export var speed: float = 100.0
@export var move_direction: Vector2 = Vector2.RIGHT
@export var turn_delay: float = 0.3
@export var wall_jump_grace_time: float = 0.15

var platform_wall_normal := Vector2.ZERO  # Renamed from last_wall_collision_normal
var grace_timer := 0.0
var turn_timer := 0.0

func _physics_process(delta: float) -> void:
	# Update timers
	grace_timer = max(grace_timer - delta, 0.0)
	turn_timer = max(turn_timer - delta, 0.0)
	
	# Store wall collision info
	if is_on_wall():
		platform_wall_normal = get_wall_normal()  # Using renamed variable
		grace_timer = wall_jump_grace_time
	
	# Movement
	velocity = move_direction * speed
	move_and_slide()
	
	# Delayed turning
	if is_on_wall() and turn_timer <= 0:
		_change_direction()
		turn_timer = turn_delay

func _change_direction() -> void:
	move_direction *= -1
	if has_node("Sprite2D"):
		$Sprite2D.flip_h = not $Sprite2D.flip_h

func get_wall_jump_normal() -> Vector2:
	return platform_wall_normal if grace_timer > 0 else Vector2.ZERO
