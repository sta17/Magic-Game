@icon("res://assets/Icons/pixel-boy/node_3D/icon_projectile.png")
extends CharacterBody3D
class_name Projectile

@onready var ray_cast_3d: RayCast3D = $RayCast3D
@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D
@onready var gpu_particles_3d: GPUParticles3D = $GPUParticles3D

@export var speed=50
var sender_node: Node3D
var destroyed:bool = false

func _ready() -> void:
	pass

func _physics_process(delta):
	
	if !destroyed:
		velocity += transform.basis * Vector3(0,0,speed) * delta
		move_and_slide()
		check_hitting()

func check_hitting():
	if !sender_node: queue_free()
	ray_cast_3d.force_raycast_update()
	var collide:bool = ray_cast_3d.is_colliding()
	if collide == true:
		var collider = ray_cast_3d.get_collider()
		# Hitting an enemy
		if collider and !collider == sender_node:
			mesh_instance_3d.visible = false
			gpu_particles_3d.emitting = true
			if collider.has_method("damage"):
				if sender_node is Player:
					collider.damage(sender_node.weapon.damage)
				
					# Creating an impact animation
					var impact = preload("res://objects/impact.tscn")
					var impact_instance = impact.instantiate()
				
					impact_instance.play("shot")
				
					get_tree().root.add_child(impact_instance)
				
					impact_instance.position = ray_cast_3d.get_collision_point() + (ray_cast_3d.get_collision_normal() / 10)
				elif sender_node is EnemyStatic or sender_node is EnemyMoving:
					collider.damage(sender_node.BaseDamage) # Apply damage to player
		
			await get_tree().create_timer(1).timeout
			#gpu_particles_3d.queue_free()
			destroyed = true
			queue_free()

func set_sender(sender:Node3D):
	sender_node = sender

func _on_timer_timeout() -> void:
	queue_free()
