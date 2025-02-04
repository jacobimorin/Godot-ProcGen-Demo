extends Node2D

# Room scene references
@export var spawn_room_scene: PackedScene
@export var end_room_scene: PackedScene
@export var room_variants: Array[PackedScene]

# Configuration
@export var min_rooms := 5
@export var max_rooms := 50
@export var grid_size := 100  # Distance between room centers

# Room tracking
var rooms: Dictionary = {}  # Position Vector2 -> Room instance
var available_doors: Array[Dictionary] = []  # {position, direction, opposite_direction}

# Define opposite directions
var opposite_directions = {
	Vector2.UP: Vector2.DOWN,
	Vector2.DOWN: Vector2.UP,
	Vector2.LEFT: Vector2.RIGHT,
	Vector2.RIGHT: Vector2.LEFT
}

func _ready():
	generate_level()

func generate_level():
	# Start with spawn room
	var spawn_room = spawn_room_scene.instantiate()
	rooms[Vector2.ZERO] = spawn_room
	add_child(spawn_room)

	# Add all doors from spawn room to available doors
	add_available_doors(spawn_room, Vector2.ZERO)

	# Generate random rooms
	var num_rooms = randi_range(min_rooms, max_rooms)
	var current_rooms = 1
	
	print("Generating level with ", num_rooms, " rooms.")

	while current_rooms < num_rooms and not available_doors.is_empty():
		# Pick a random available door
		var door_index = randi() % available_doors.size()
		var door_info = available_doors[door_index]

		# Try to place a room
		if try_place_room(door_info):
			current_rooms += 1

		# Remove used door
		available_doors.remove_at(door_index)

	# Place end room at the last available door
	if not available_doors.is_empty():
		var last_door = available_doors[0]
		place_end_room(last_door)

func try_place_room(door_info: Dictionary) -> bool:
	var source_pos = door_info.position
	var direction = door_info.direction
	var opposite_direction = door_info.opposite_direction

	# Calculate new room position
	var new_pos = source_pos + (direction * grid_size)

	# Check if position is already occupied
	if rooms.has(new_pos):
		return false

	# Find a compatible room variant that has a matching entrance
	var compatible_room = find_compatible_room(opposite_direction)
	if not compatible_room:
		print("No compatible room found for direction: ", direction)
		return false

	# Place the room
	var room_instance = compatible_room.instantiate()
	rooms[new_pos] = room_instance
	add_child(room_instance)
	room_instance.position = new_pos  # Ensure correct positioning

	# Add new available doors
	add_available_doors(room_instance, new_pos)

	return true

func find_compatible_room(required_door: Vector2) -> PackedScene:
	var shuffled_variants = room_variants.duplicate()
	shuffled_variants.shuffle()

	for variant in shuffled_variants:
		var test_room = variant.instantiate()
		if has_required_door(test_room, required_door):
			test_room.queue_free()
			return variant
		test_room.queue_free()

	return null

func has_required_door(room: Node2D, direction: Vector2) -> bool:
	# Check if the room has a door in the required direction
	for child in room.get_children():
		if child is Marker2D and child.name.begins_with("Door"):
			var door_pos = (child.global_position - room.global_position).normalized()
			if door_pos == direction:
				return true
	return false

func add_available_doors(room: Node2D, grid_pos: Vector2):
	for child in room.get_children():
		if child is Marker2D and child.name.begins_with("Door"):
			var direction = (child.global_position - room.global_position).normalized()
			var opposite_direction = opposite_directions.get(direction, Vector2.ZERO)
			var new_pos = grid_pos + direction

			# Only add the door if the position is unoccupied
			if not rooms.has(new_pos):
				available_doors.append({
					"position": grid_pos,
					"direction": direction,
					"opposite_direction": opposite_direction
				})

func place_end_room(door_info: Dictionary):
	var end_pos = door_info.position + (door_info.direction * grid_size)
	var end_room = end_room_scene.instantiate()
	rooms[end_pos] = end_room
	add_child(end_room)
	end_room.position = end_pos
