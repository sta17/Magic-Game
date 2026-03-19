extends CharacterBody3D
class_name EnemyMoving

@export_subgroup("Game Stats")
@export var BaseDamage:float = 5
@export var attackRate:float = 0.25
@export var health := 100
var dead := false
@export var turretShooting := false
@export var speed=50

@export_subgroup("Targetting")
@export var attack_distance=5.0
@export var search_distance=10.0
var player:Node3D
@export var RotSpeedX:float = 0.5
@export var RotSpeedY:float = 0
@export var RotSpeedZ:float = 0
var time := 0.0
var bobing_position:Vector3
var current_target:Node3D
var valid_target_in_range = false

@export_subgroup("Moddeling")
@export var doBobUpAndDown:bool
@export var raycast:RayCast3D
@export var MuzzleContainerNode:Node3D
@export var model:Node3D
var projectileBullet=load("res://objects/Projectile.tscn")
var muzzleArray

# When ready, save the initial position
func _ready():
	if !model:
		model = self
	player = get_tree().get_nodes_in_group("Player")[0]
	
	$Timer.wait_time = attackRate
	bobing_position = Vector3(0,position.y,0)
	muzzleArray = MuzzleContainerNode.get_children()
	raycast.target_position.z=search_distance

func _process(delta):
	if visible:
		
		var playerPos: Vector3 = Vector3(0, 0, 0)
		if player:
			playerPos = player.position
		
		raycast.look_at(playerPos, Vector3.UP, true)
		raycast.force_raycast_update()
		valid_target_in_range = false
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			if collider is Player:
				current_target = collider
				
				var origin = raycast.global_transform.origin
				var collision_point = raycast.get_collision_point()
				var distance = origin.distance_to(collision_point)
				
				if distance > attack_distance:
					position += transform.basis * Vector3(0,0,speed) * delta
					valid_target_in_range = true
				else:
					valid_target_in_range = false
			else:
				current_target = null
		else:
			current_target = null
		
		if current_target:
			if RotSpeedX == 0:
				model.look_at(playerPos + Vector3(0, RotSpeedX, 0), Vector3.UP, true) # Look at player
			else:
				model.look_at(playerPos, Vector3.UP, true) # Look at player
		
		if doBobUpAndDown:
			# Sine movement (up and down)
			bobing_position.y += (cos(time * 5) * 1) * delta
			position = Vector3(position.x,bobing_position.y,position.z)
	time += delta
	move_and_slide()

# Take damage from player
func damage(amount):
	Audio.play("assets/audio/enemy_hurt.ogg")
	
	health -= amount
	if health <= 0 and !dead:
		destroy()

# Destroy the enemy when out of health
func destroy():
	Audio.play("assets/audio/enemy_destroy.ogg")
	
	dead = true
	queue_free()

# Shoot when timer hits 0
func _on_timer_timeout():
	if current_target:
		# Play muzzle flash animation(s)
		Audio.play("assets/audio/enemy_attack.ogg")
		
		for muzzle in muzzleArray:
			muzzle.frame = 0
			muzzle.play("default")
			muzzle.rotation_degrees.z = randf_range(-45, 45)

			var instance=projectileBullet.instantiate()
			instance.position=muzzle.global_position
			instance.transform.basis=muzzle.global_transform.basis
			instance.set_sender(self)
			get_parent().add_child((instance))

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Player:
		valid_target_in_range = true

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body is Player:
		valid_target_in_range = false
