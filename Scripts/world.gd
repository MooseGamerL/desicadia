#Code for a Healthbar
extends Node2D

#Variables used to update the healthbar.
@onready var player: CharacterBody2D
@onready var health_bar: ProgressBar

#Code to update the healthbar
func _ready() -> void:
	player = $CharacterBody2D
	health_bar = $UI/HealthBar/ProgressBar
	if player and player.has_method("set_health_bar"):
		player.set_health_bar(health_bar)
		player.update_health_bar()
	connect_pickup_signals()

# This function listens for signals from the the pickup scenes
func connect_pickup_signals() -> void:
	var pickups = get_tree().get_nodes_in_group("pickup")
	for pickup in pickups:
		if pickup.has_signal("ability_picked_up"):
			pickup.ability_picked_up.connect(_on_ability_picked_up)

# Signals are then passed on to the player script with the ability
func _on_ability_picked_up(ability_type: String):
	print("World recived pickup signal: ", ability_type)
	if player and player.has_method("on_ability_picked_up"):
		player.on_ability_picked_up(ability_type)
	else:
		print("Player not found or missing on on_ability_picked_up function")
