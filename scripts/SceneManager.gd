extends Node3D

var next_scene = null
var spawn_point = null
@onready var current_scene_holder:Node3D = $CurrentScene
@onready var player = $Player
@onready var ninePatchRect = $"Fade To Black/NinePatchRect"
@onready var animationPlayer = $"Fade To Black/AnimationPlayer"
@onready var label = $"Fade To Black/NinePatchRect/Panel/Label"

var player_mode
var scene

var startTransition: bool = false
var startNewScene:bool = false

var startNewSceneNoFade:bool = false

func _ready():
	ninePatchRect.visible = false

func transition_to_scene(new_scene:String,goto_point:String=""):
	next_scene = new_scene
	spawn_point = goto_point
	
	#transition_to_sceneWithOutFade(new_scene,goto_point)
	animationPlayer.play("FadeToBlack")
	
func _process(delta):
	if startTransition:
		HandleOldScene()
	elif(startNewScene):
		StartNewScene()
	elif(startNewSceneNoFade):
		transition_to_sceneWithOutFade_NextStage()
	
func AfterFadeToBlack():
	startTransition = true
	
func HandleOldScene():
	# Change transition code here.
	var localSceneHandler = current_scene_holder.get_child(0)
	localSceneHandler.queue_free()

	scene = load(next_scene).instantiate()
	
	var area_Name:String = scene.Area_Display_Name[spawn_point]
	area_Name = "  " + area_Name
	label.text = area_Name
	
	# Set Player Location in scene,
	var player_spawn_point:Vector3 = scene.get_spawn_point(spawn_point)
	player.set_location(player_spawn_point)
	
	startTransition = false
	startNewScene = true

func StartNewScene():
	current_scene_holder.add_child(scene)

	animationPlayer.play("FadeToNormal")

func AfterFateToNormal():
	startNewScene = false
	animationPlayer.play("Show Sign")

func displayAreaName():
	animationPlayer.play("Show Sign")

func transition_to_sceneWithOutFade(new_scene:String,goto_point:String=""):
	next_scene = new_scene
	spawn_point = goto_point
	
	# Change transition code here.
	var localSceneHandler = current_scene_holder.get_child(0)
	localSceneHandler.queue_free()

	scene = load(next_scene).instantiate()
	
	# Set Player Location in scene,
	var player_spawn_point:Vector3 = scene.get_spawn_point(spawn_point)
	player.set_location(player_spawn_point)
	
	current_scene_holder.add_child(scene)
	
	startNewSceneNoFade = true

func transition_to_sceneWithOutFade_NextStage():
	current_scene_holder.add_child(scene)
	startNewSceneNoFade = false

func On():
	# turn player on again.
	player.set_process(true)
	player.set_process_input(true)
	get_tree().paused = false
	player.start_inputs()
	current_scene_holder.set_block_signals(false)
	player.visible = true
	player.process_mode = player_mode

func Off():
		# turn player off to prevent triggering things.
	player.stop_inputs()
	player.set_process(false)
	player.set_process_input(false)
	player.visible = false
	player_mode = player.process_mode
	player.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().paused = true
	current_scene_holder.set_block_signals(true)
