extends Area2D

@export var pickup_groups: Array[String] = ["player"]
@export var ability_type: String = "wall_jump"  # wall_jump, dash, double_jump, slam
signal ability_picked_up(ability_type: String, ability_name: String, ability_description: String)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	
	# Add to pickup group
	add_to_group("pickup")
	# Connect the body_entered signal
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	print("🔍 Pickup detected collision with: ", body.name)
	if body.is_in_group("player"):
		print("🎯 PLAYER COLLECTED PICKUP:  (", ability_type, ")")
		# Emit signal with ability information
		ability_picked_up.emit(ability_type)
		print("📡 Signal emitted: ability_picked_up")
		
		# Play pickup animation/effect here if desired
		# For now, just queue_free to make it disappear
		queue_free()
	else:
		print("❌ Collision with non-player: ", body.name, " (Groups: ", body.get_groups(), ")")
