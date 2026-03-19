extends StaticBody3D
class_name Door

@onready var animation_player: AnimationPlayer = $AnimationPlayer
var isDoorOpen = false

func openDoor() -> void:
	animation_player.play("OpenDoor")
	isDoorOpen = true
	
func closeDoor() -> void:
	animation_player.play("CloseDoor")
	isDoorOpen = false

func OpenCloseDoor():
	if isDoorOpen:
		closeDoor()
	else:
		openDoor()

func getDoorStatus() -> bool:
	return isDoorOpen
