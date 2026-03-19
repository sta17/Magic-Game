@icon("res://assets/Icons/pixel-boy/node_3D/icon_door.png")
extends StaticBody3D
class_name SceneTransition

@export_file var next_scene_path = ""
@export var spawn_point:String = ""

# use this as base for respawn, potentially + some in the y to stay on the ground rather in it.

func Transition():
	var node = get_node(NodePath("/root/Start/SceneManager"))
	node.transition_to_scene(next_scene_path,spawn_point)
