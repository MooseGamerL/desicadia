extends CharacterBody2D

@export var speed: float = 100.0
@export var move_direction: Vector2 = Vector2.RIGHT
@export var turn_delay: float = 0.3

@export var gravity: float = 980.0
@export var max_fall_speed: float = 400.0
@export var damage: float = 4
@export var damage_cooldown: float = 1.0

var damage_timer := 0.0
var turn_timer := 0.0

func _physics_process(delta: float) -> void:
	turn_timer = max(turn_timer - delta, 0.0)
	damage_timer = max(damage_timer - delta, 0.0)
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	velocity.x = move_direction.x * speed
	move_and_slide()
	if is_on_wall():
		change_direction()
	check_player_collision()

func _ready():
	add_to_group("enemy")
	collision_layer = 2
	collision_mask = 1

func check_player_collision() -> void:
	if damage_timer > 0:
		return
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.has_method("take_damage"):
			collider.take_damage(damage)
			print("Enemy hit player!")
			damage_timer = damage_cooldown
			break

func change_direction() -> void:
	if turn_timer > 0:
		return
	move_direction *= -1
	turn_timer = turn_delay
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.flip_h = not $AnimatedSprite2D.flip_h
