extends Node3D

var startScene: String = "res://scenes/TestWorld.tscn"

func _ready():
	$SceneManager.transition_to_sceneWithOutFade(startScene,"Start")

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit() # default behavior
		# Later handle exit behavior
