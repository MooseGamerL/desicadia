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
