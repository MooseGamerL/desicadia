extends Node2D

# Simple pickup wrapper - just set the ability_type property in the inspector!
@export var ability_type: String = "wall_jump"  # wall_jump, dash, double_jump, slam

func _ready() -> void:
	# Instantiate the pickup scene
	var pickup_scene = preload("res://Scenes/Pickup.tscn").instantiate()
	add_child(pickup_scene)
	
	# Get the Area2D from the instantiated pickup
	var area2d = pickup_scene.get_node("Area2D")
	if area2d:
		# Set the ability type from the export property
		area2d.ability_type = ability_type
		print("🎯 Pickup wrapper created with ability: ", ability_type)
	else:
		print("❌ Could not find Area2D in pickup scene")
