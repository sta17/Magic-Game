extends StaticBody3D
class_name EnemyStatic

@export_subgroup("Game Stats")
@export var BaseDamage:float = 5
@export var attackRate:float = 0.25
@export var health := 100
@export var health_max := 100
var dead := false
@export var turretShooting := false

@export_subgroup("Targetting")
var player:Node3D
@export var RotSpeedX:float = 0.5
@export var RotSpeedY:float = 0
@export var RotSpeedZ:float = 0
var time := 0.0
var target_position:Vector3
var valid_target_in_range = false

@export_subgroup("Moddeling")
@export var doBobUpAndDown:bool
@export var raycast:RayCast3D
@export var MuzzleContainerNode:Node3D
@export var model:Node3D
var projectileBullet=load("res://objects/Projectile.tscn")
var muzzleArray
@onready var particles_trail: CPUParticles3D = $ParticlesTrail


# When ready, save the initial position
func _ready():
	if !model:
		model = self
	player = get_tree().get_nodes_in_group("Player")[0]
	
	$Timer.wait_time = attackRate
	target_position = position
	muzzleArray = MuzzleContainerNode.get_children()

func _process(delta):
	if visible:
		var playerPos: Vector3 = Vector3(0, 0, 0)
		if player:
			playerPos = player.position
		if RotSpeedX == 0:
			model.look_at(playerPos + Vector3(0, RotSpeedX, 0), Vector3.UP, true) # Look at player
		else:
			model.look_at(playerPos, Vector3.UP, true) # Look at player
		
		if doBobUpAndDown:
			target_position.y += (cos(time * 5) * 1) * delta # Sine movement (up and down)
			position = target_position
	time += delta

# Take damage from player
func damage(amount):
	
	Audio.play("assets/audio/enemy_hurt.ogg")
	
	health -= amount
	
	if health < health_max:
		particles_trail.emitting = true
	
	if health <= 0 and !dead:
		destroy()

# Destroy the enemy when out of health
func destroy():
	Audio.play("assets/audio/enemy_destroy.ogg")
	particles_trail.queue_free()
	
	dead = true
	queue_free()

# Shoot when timer hits 0
func _on_timer_timeout():
	raycast.force_raycast_update()
	
	if raycast.is_colliding() or (turretShooting and valid_target_in_range):
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
