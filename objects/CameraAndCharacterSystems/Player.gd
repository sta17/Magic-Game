extends CharacterBody3D
class_name Player

#region Variables
@export_subgroup("Properties")
@export var speed = 10
@export var acceleration = 4
@export var jump_strength = 13
@export var jump_movement_reduction = 2
@export var rotation_speed = 12
@export var health:float = 100
@export var health_max:float = 100
signal health_updated

## Main [InventoryHandler] node.
@export_subgroup("Inventory")
@onready var inventoryHandler = $InventoryHandler
@onready var inventorySystemUI = $"HUD/Inventory System UI"
var interactableInv
var interactableInvBody:BoxInventory
var interactibleItem:PickUpItem
var interactableDoor:Door

@export_subgroup("Weapons")
@export var weapons: Array[Weapon] = []
var weapon: Weapon
var weapon_index := 0
var container_offset = Vector3(1.2, -1.1, -2.75)
var tween:Tween
@onready var container = $Container
@onready var muzzle = $Muzzle
@onready var rightHand: BoneAttachment3D = $SpaceRanger/Rig/Skeleton3D/HandSlotRight
@onready var attack_cooldown = $Cooldown
@onready var crosshair:TextureRect = $HUD/Crosshair
var projectileBullet=load("res://objects/Projectile.tscn")

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var jumping = false
var jump_single = false
var jump_double = false
var last_floor = true
var attacks = [
	"1H_Attack_Slice_Diagonal",
	"1H_Attack_Stab"#,
	#"1H_Attack_Chop"
]

var mouse_captured := true
var input_mouse: Vector2

@onready var raycast = $RayCast
@onready var particles_trail = $ParticlesTrail
@onready var sound_footsteps = $SoundFootsteps
@onready var interact_message_position : Control = $HUD/InteractMessagePosition
@onready var interact_message : Label = $HUD/InteractMessagePosition/InteractMessage

@onready var anim_tree = $SpaceRanger/AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")
var cameraController

var allowMovement:bool = true
enum INPUT_STATE {
	IDLE,
	UI_OPEN_MAINMENU,
	UI_OPEN_INVENTORY,
	STOPPED_INPUT,
}
var _INTERFACE_INPUT_STATE:INPUT_STATE = INPUT_STATE.IDLE
#endregion

#region Ready and Process
func _ready():
	initiate_change_weapon(weapon_index)
	cameraController = get_tree().get_nodes_in_group("CameraController")[0]

func _physics_process(delta):
	# Handle functions
	handle_controls(delta)
	
	if allowMovement:
		var working_speed = speed
		if jumping:
			working_speed = working_speed/jump_movement_reduction
		var Velocity = velocity
		var inputDir: Vector2 = Input.get_vector("move_right","move_left","move_back","move_forward")
		var direction = Vector3(transform.basis * Vector3(inputDir.x,0,inputDir.y)).normalized()
		if direction != Vector3.ZERO:
			Velocity.x = direction.x * working_speed
			Velocity.z = direction.z * working_speed
		else:
			Velocity.x = move_toward(velocity.x,0,working_speed)
			Velocity.z = move_toward(velocity.z,0,working_speed)
		# Add Velocity and gravity
		velocity.x = Velocity.x
		velocity.z = Velocity.z
		
		# Add the gravity.
		if not is_on_floor():
			velocity.y -= gravity * delta
		
		# Handle Jump.
		# We just hit the floor after being in the air
		if is_on_floor() and not last_floor:
			jumping = false
			Audio.play("assets/audio/land.ogg")
			anim_tree.set("parameters/conditions/grounded", true)
			anim_tree.set("parameters/conditions/jumping", jumping)
		# We're in the air, but we didn't jump
		if not is_on_floor() and not jumping:
			anim_state.travel("Jump_Idle")
			anim_tree.set("parameters/conditions/grounded", false)
		last_floor = is_on_floor()
		
		var vl = velocity * transform.basis
		anim_tree.set("parameters/IWR/blend_position", Vector2(-vl.x, vl.z) / speed)
		
		var cameraRotation = cameraController.global_transform.basis.get_euler()
		rotation.y = cameraRotation.y+deg_to_rad(180)
		
		move_and_slide()
		interact()

func interact():
	if raycast.is_colliding():
		var object = raycast.get_collider()
		var node = object as Node
		var camera3d: Camera3D = get_tree().get_nodes_in_group("CameraController")[0].camera

		var door := node as Door
		if door:
			interact_message.visible = true
			interact_message.text = "E to Open Door"
			interact_message_position.position = camera3d.unproject_position(door.position)
			interactableDoor = door
			if Input.is_action_just_pressed("interact"):
				door.OpenCloseDoor()
			return
		var box := node as BoxInventory
		if box:
			var inv = box.get_inventory()
			if inv != null:
				interactableInvBody = box
				if allowMovement:
					interact_message.visible = !inventoryHandler.is_open(inv)
				interact_message.text = "E to Open Inventory"
				interact_message_position.position = camera3d.unproject_position(interactableInvBody.position)
				if interactableInv != inv:
					if Input.is_action_just_pressed("interact"):
						open_inventory(inv)
				return
		var dropped_item := node as PickUpItem
		if dropped_item:
			if dropped_item.is_pickable:
				interactibleItem = dropped_item
				interact_message.visible = true
				interact_message.text = "E to Pickup"
				interact_message_position.position = camera3d.unproject_position(interactibleItem.position)
				
				if Input.is_action_just_pressed("interact"):
					var result = interactibleItem.Collect(self)
					if result: interactibleItem = null
				return
		interact_message.visible = false

func _process(delta):
	# Movement sound
	if is_on_floor():
		if abs(velocity.x) > 1 or abs(velocity.z) > 1:
			particles_trail.emitting = true
			sound_footsteps.stream_paused = false
		else:
			particles_trail.emitting = false
			sound_footsteps.stream_paused = true
	else:
		particles_trail.emitting = false
		sound_footsteps.stream_paused = true
	
	# Falling/respawning
	if position.y < -10:
		get_tree().reload_current_scene()

func handle_controls(delta):
	if Input.is_action_just_pressed("negative_interact"):
		if _INTERFACE_INPUT_STATE == INPUT_STATE.UI_OPEN_INVENTORY:
			open_inventory(getInventory())
	if Input.is_action_just_pressed("toggle_main_menu"):
		get_tree().quit()
	if Input.is_action_just_pressed("toggle_inventory"):
		open_inventory(getInventory())
	if Input.is_action_just_pressed("interact"):
		if interactableInv:
			open_inventory(interactableInv)
		if interactibleItem:
			var result = interactibleItem.Collect(self)
			if result:
				interactibleItem = null
		if interactableDoor:
			interactableDoor.OpenCloseDoor()
	
	if Input.is_action_just_pressed("toggle_hotbar_next"):
		inventoryHandler.hotbar.next_item()
	if Input.is_action_just_pressed("toggle_hotbar_previous"):
		inventoryHandler.hotbar.previous_item()
	
	# Mouse capture
	if Input.is_action_just_pressed("mouse_capture") and allowMovement:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_captured = true
	if Input.is_action_just_pressed("mouse_capture_exit") and allowMovement:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_captured = false
		input_mouse = Vector2.ZERO
	
	# Jumping
	if !is_on_floor() and Input.is_action_just_pressed("jump"):
			velocity.y = +jump_strength
			jump_double = true
			jump_single = false
	elif is_on_floor() and Input.is_action_just_pressed("jump"):
			velocity.y = +jump_strength
			jumping = true
			jump_single = true
			anim_tree.set("parameters/conditions/grounded", false)
			anim_tree.set("parameters/conditions/jumping", jumping)
			Audio.play("assets/audio/jump_a.ogg, assets/audio/jump_b.ogg, assets/audio/jump_c.ogg")
	
	# Shooting
	if Input.is_action_pressed("attack") and allowMovement:
		if weapon.is_melee:
			anim_state.travel(attacks.pick_random())
			weapon_melee()
		else:
			anim_state.travel("1H_Ranged_Shoot")
			weapon_ranged()
	# Weapon switching
	if Input.is_action_just_pressed("toggle_weapon_next") and allowMovement:
		weapon_index = wrap(weapon_index + 1, 0, weapons.size())
		initiate_change_weapon(weapon_index)
		Audio.play("assets/audio/weapon_change.ogg")
	if Input.is_action_just_pressed("toggle_weapon_previous") and allowMovement:
		weapon_index = wrap(weapon_index - 1, 0, weapons.size())
		initiate_change_weapon(weapon_index)
		Audio.play("assets/audio/weapon_change.ogg")
#endregion

#region Weapon Attack
func weapon_melee():
	if !attack_cooldown.is_stopped(): return # Cooldown for shooting
	Audio.play(weapon.sound_shoot)
	attack_cooldown.start(weapon.cooldown)
	
	# Shoot the weapon, amount based on shot count
	for n in weapon.shot_count:
		raycast.target_position.x = randf_range(-weapon.spread, weapon.spread)
		raycast.target_position.y = randf_range(-weapon.spread, weapon.spread)
		raycast.force_raycast_update()
		
		if !raycast.is_colliding(): return # Don't create impact when raycast didn't hit
		var collider = raycast.get_collider()
		
		# Hitting an enemy
		if collider.has_method("damage"):
			collider.damage(weapon.damage)
			
			# Creating an impact animation
			var impact = preload("res://objects/impact.tscn")
			var impact_instance = impact.instantiate()
			impact_instance.play("shot")
			get_tree().root.add_child(impact_instance)
			impact_instance.position = raycast.get_collision_point() + (raycast.get_collision_normal() / 10)

func weapon_ranged():
	if !attack_cooldown.is_stopped(): return # Cooldown for shooting
	Audio.play(weapon.sound_shoot)
	
	# Set muzzle flash position, play animation
	muzzle.play("default")
	muzzle.rotation_degrees.z = randf_range(-45, 45)
	muzzle.scale = Vector3.ONE * randf_range(0.40, 0.75)
	
	attack_cooldown.start(weapon.cooldown)
	# Shoot the weapon, amount based on shot count
	#for n in weapon.shot_count:
	raycast.target_position.x = randf_range(-weapon.spread, weapon.spread)
	raycast.target_position.y = randf_range(-weapon.spread, weapon.spread)
	
	#raycast.force_raycast_update()
	
	var instance:Projectile=projectileBullet.instantiate()
	instance.position=muzzle.global_position
	instance.transform.basis=muzzle.global_transform.basis
	instance.set_sender(self)
	get_parent().add_child((instance))
#endregion

#region Weapon Change
# Initiates the weapon changing animation (tween)
func initiate_change_weapon(index):
	weapon_index = index
	
	tween = get_tree().create_tween()
	tween.set_ease(Tween.EASE_OUT_IN)
	tween.tween_property(container, "position", container_offset - Vector3(0, 1, 0), 0.1)
	tween.tween_callback(change_weapon) # Changes the model

# Switches the weapon model (off-screen)
func change_weapon():
	weapon = weapons[weapon_index]
	
	# Step 1. Remove previous weapon model(s) from container
	for n in rightHand.get_children():
		rightHand.remove_child(n)
	
	# Step 2. Place new weapon model in container
	var weapon_model = weapon.model.instantiate()
	rightHand.add_child(weapon_model)
	
	weapon_model.position = weapon.position
	weapon_model.rotation_degrees = weapon.rotation
	
	# Step 3. Set model to only render on layer 2 (the weapon camera)
	for child in weapon_model.find_children("*", "MeshInstance3D"):
		child.layers = 2
	
	# Set weapon data
	raycast.target_position = Vector3(0, 0, -1) * weapon.max_distance
	crosshair.texture = weapon.crosshair
	
	# Set muzzle Position
	#container.position.z += 0.25 # Knockback of weapon visual
	muzzle.position = weapon.muzzle_position #- container.position
	
#endregion

#region Take Damage
func damage(amount):
	health -= amount
	
	if health <= 0:
		health = 0
		death()
	
	health_updated.emit(health) # Update health on HUD

func death():
	get_tree().reload_current_scene() # Reset when out of health

func heal(amount):
	health += amount
	
	if health > health_max:
		health = health_max
	
	health_updated.emit(health) # Update health on HUD
#endregion

#region Items

func _on_inventory_system_ui_opened_inventory_ui(opened) -> void:
	allowUI(opened)

func open_inventory(inventory : Inventory = null):
	if _INTERFACE_INPUT_STATE == INPUT_STATE.IDLE:
		_INTERFACE_INPUT_STATE = INPUT_STATE.UI_OPEN_INVENTORY
		allowUI(allowMovement)
		inventorySystemUI.open_inventory(inventory)
	else:
		_INTERFACE_INPUT_STATE = INPUT_STATE.IDLE
		allowUI(allowMovement)
		inventorySystemUI.open_inventory(inventory)

func allowUI(status:bool):
	if status:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_captured = false
		crosshair.visible = false
		interact_message.visible = false
		allowMovement = false
		cameraController.allowUI(status)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_captured = true
		crosshair.visible = true
		allowMovement = true
		cameraController.allowUI(status)

func getInventoryHandler():
	return $InventoryHandler

func getInventory():
	var inventoryHandler:InventoryHandler = $InventoryHandler
	return inventoryHandler.inventory

#endregion

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is PickUpItem:
		if !interactibleItem: interactibleItem = body
		if body.autoCollect:
			body.Collect(self)
	if body is BoxInventory:
		interactableInv = body.get_inventory()
		interactableInvBody = body
	if body is Door:
		interactableDoor = body

func _on_area_3d_body_exited(body: Node3D) -> void:
	pass # Replace with function body.
	if body is BoxInventory and body == interactableInvBody:
		interactableInvBody = null
		interactableInv = null
	if body is PickUpItem and body == interactibleItem:
		interactibleItem = null
	if body is SceneTransition:
		body.Transition()
	if body is Door and interactableDoor == body:
		interactableDoor = null

func stop_inputs():
	_INTERFACE_INPUT_STATE = INPUT_STATE.STOPPED_INPUT

func start_inputs():
	_INTERFACE_INPUT_STATE = INPUT_STATE.IDLE

func set_location(location:Vector3):
	global_transform.origin = location
