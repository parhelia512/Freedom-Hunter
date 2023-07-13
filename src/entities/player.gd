extends "entity.gd"
class_name Player


const Inventory = preload("res://src/inventory.gd")

onready var yaw_node = get_node("/root/game/yaw")
onready var camera_node = yaw_node.get_node("pitch/camera")
onready var camera_offset = yaw_node.get_translation().y

onready var hud = get_node("/root/hud/margin/view")
onready var onscreen = get_node("/root/hud/onscreen")

var equipment = {"weapon": null, "armour": {"head": null, "torso": null, "rightarm": null, "leftarm": null, "leg": null}}
var inventory: Inventory = preload("res://data/scenes/inventory.tscn").instance()
var money = 10000


func _init():
	# Start with 50 HP to recover
	hp_max = 150
	hp_regenerable = 150


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		inventory.free()


func set_equipment(model, bone, _name=null):
	var skel = $Armature/Skeleton
	for node in skel.get_children():
		if node is BoneAttachment:
			if node.get_bone_name() == bone:
				node.add_child(model)
				if _name != null:
					node.set_name(name)
				return
	var ba = BoneAttachment.new()
	if _name != null:
		ba.set_name(_name)
	ba.set_bone_name(bone)
	ba.add_child(model)
	skel.add_child(ba)


func _ready():
	# TEST CODE
	equipment.weapon = load("res://data/scenes/equipment/weapon/lasersword/laser_sword.tscn").instance()
	set_equipment(equipment.weapon, "weapon_L", "weapon")

	inventory.set_position(Vector2(1370, 200))
	inventory.set_name("player_inventory")

	resume_player()


func sort_by_distance(a, b):
	var dist_a = (get_global_transform().origin - a.get_global_transform().origin).length()
	var dist_b = (get_global_transform().origin - b.get_global_transform().origin).length()
	return dist_a < dist_b


func get_nearest_interact():
	var areas = $interact.get_overlapping_areas()
	var interacts = []
	for area in areas:
		if area.is_in_group("interact"):
			interacts.append(area)
	if interacts.size() > 0:
		interacts.sort_custom(self, "sort_by_distance")
		return interacts[0]
	return null


func interact_with(interact):
	if interact != null and not hud.get_node("notification/animation").is_playing():
		interact.get_parent().interact(self, interact)


func interact_with_nearest():
	interact_with(get_nearest_interact())


func _input(event):
	if event.is_action_pressed("player_attack_left"):
		attack("left_attack_0")
	elif event.is_action_pressed("player_attack_right"):
		attack("right_attack_0")
	elif event.is_action_pressed("player_dodge"):
		if $AnimationTree["parameters/conditions/running"]:
			jump()
		else:
			dodge()
	elif event.is_action_pressed("player_run"):
		run()
	elif event.is_action_released("player_run"):
		walk()
	elif event.is_action_pressed("player_interact"):
		interact_with_nearest()


func add_item(item):
	item = item.clone()
	var remainder = inventory.add_item(item)
	return remainder


func buy_item(item, cost):
	if item.quantity > 0 and money >= cost:
		money -= cost
		add_item(item)
		return true
	return false


func drop_item_on_floor(item):
	var drop_origin = $drop_item.global_transform.origin
	item.global_transform.origin = drop_origin
	get_parent().add_child(item)


func get_defence():
	var defence = 0
	for piece in equipment.armour.values():
		if piece != null:
			defence += piece.strength
	return defence


sync func died():
	.died()
	$AnimationPlayer.play("death")
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	if not get_tree().has_network_peer() or is_network_master():
		hud.prompt_respawn()
	$shape.disabled = true


func respawn():
	.respawn()
	resume_player()
	$shape.disabled = false


func pause_player():
	direction = Vector3()
	set_process_input(false)
	set_physics_process(false)
	set_process(false)
	$AnimationPlayer.play("idle-loop")


func resume_player():
	var enable = not get_tree().has_network_peer() or is_network_master()
	set_process_input(enable)
	set_physics_process(enable)
	set_process(true)


func _process(_delta):
	if state_machine.get_current_node() == "dead" and \
			get_tree().has_network_peer() and \
			not is_network_master():
		direction = (previous_origin - transform.origin).normalized()
		previous_origin = transform.origin


func _physics_process(delta):
	var current_state := state_machine.get_current_node()
	if current_state != "dodge":
		direction = Vector3(0, 0, 0)
		var camera = camera_node.get_global_transform()
		# Player movements
		var input = Vector3()
		if Input.is_action_pressed("player_forward"):
			input -= camera.basis.z * Input.get_action_strength("player_forward")
		if Input.is_action_pressed("player_backward"):
			input += camera.basis.z * Input.get_action_strength("player_backward")
		if Input.is_action_pressed("player_left"):
			input -= camera.basis.x * Input.get_action_strength("player_left")
		if Input.is_action_pressed("player_right"):
			input += camera.basis.x * Input.get_action_strength("player_right")
		direction = input * Vector3(1, 0, 1)  # remove Y component from direction

		if onscreen.is_visible():
			var d = onscreen.direction
			direction = d.y * camera.basis.z + d.x * camera.basis.x

		direction = direction.normalized()
		if direction != Vector3():
			if current_state == "idle-loop":
				walk()
			if Input.is_action_pressed("player_run"):
				run()
		else:
			stop()

	# Player collision and physics
	move_entity(delta)

	# Camera follows the player
	yaw_node.set_translation(get_translation() + Vector3(0, camera_offset, 0))
