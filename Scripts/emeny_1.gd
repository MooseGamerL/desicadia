#Enemy code.
extends CharacterBody2D

#Movement variables.
@export var speed: float = 100.0
@export var move_direction: Vector2 = Vector2.RIGHT
@export var turn_delay: float = 0.3
@export var gravity: float = 980.0
@export var max_fall_speed: float = 400.0
var turn_timer := 0.0

#Damage variables.
@export var damage: float = 1
@export var damage_cooldown: float = 1.0
var damage_timer := 0.0

#Death and respawn variables.
@export var respawn_time: float = 5.0
var is_dead := false
var respawn_timer := 0.0
var initial_position: Vector2
var initial_direction: Vector2
var death_invulnerability_timer := 0.0
var killed_by_slam := false

#This function updates timers, applies gravity if airborne, moves horizontally, reverses direction on wall contact, and handles death and player collisions.
func _physics_process(delta: float) -> void:
	if is_dead:
		death_invulnerability_timer = max(death_invulnerability_timer - delta, 0.0)
		respawn_timer = max(respawn_timer - delta, 0.0)
		if respawn_timer <= 0:
			respawn()
		return
	turn_timer = max(turn_timer - delta, 0.0)
	damage_timer = max(damage_timer - delta, 0.0)
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	else:
		velocity.y = 0
		
	velocity.x = move_direction.x * speed
	move_and_slide()
	if is_on_wall():
		change_direction()
	check_player_collision()

#This function sets the enemy’s group, collision layers, and stores its starting position and movement direction.
func _ready():
	add_to_group("enemy")
	collision_layer = 2
	collision_mask = 1
	initial_position = position
	initial_direction = move_direction

#This function damages the player on contact unless the player is above the enemy or the enemy is invulnerable, then starts a damage cooldown.
func check_player_collision() -> void:
	if damage_timer > 0 or is_dead or death_invulnerability_timer > 0:
		return
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.has_method("take_damage"):
			var collision_normal = collision.get_normal()
			# Check if player is above enemy
			if collision_normal.y > 0.5:
				# Player is above enemy, don't damage
				return
			collider.take_damage(damage)
			damage_timer = damage_cooldown
			break

#This function hides the enemy and makes it not have collision after it has been killed, and starts the respawn timer.
func die() -> void:
	is_dead = true
	death_invulnerability_timer = 0.1
	respawn_timer = respawn_time
	collision_layer = 0
	collision_mask = 0
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.visible = false

#This function flips the enemy’s movement direction and sprite horizontally, with a turn delay and only if the enemy isn’t dead.
func change_direction() -> void:
	if turn_timer > 0 or is_dead:
		return
	move_direction *= -1
	turn_timer = turn_delay
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.flip_h = not $AnimatedSprite2D.flip_h

#This function makes the enemy visible again and gives it collision.
func respawn() -> void:
	is_dead = false
	death_invulnerability_timer = 0.0
	respawn_timer = 0.0
	position = initial_position
	move_direction = initial_direction
	velocity = Vector2.ZERO
	collision_layer = 2
	collision_mask = 1
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.visible = true
		$AnimatedSprite2D.flip_h = false
