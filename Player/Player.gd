extends CharacterBody2D

@onready var anim = get_node("AnimatedSprite2D")

func _process(delta):
	velocity.y += 400 * delta  # Apply gravity
	position += velocity * delta
	
	if is_on_floor():
		queue_free()
		restart_game()
	
	if Input.is_action_just_pressed("ui_up") and position.y > 0:
		anim.play('Set')
	elif Input.is_action_just_released('ui_up'):
		velocity.y = -200
		anim.play('Float')
		
	move_and_slide()
	
func restart_game():
	var new_scene_path = "res://main.tscn"
	get_tree().change_scene_to_file(new_scene_path)

# const SPEED = 300.0
# const JUMP_VELOCITY = -400.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
# var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# @onready var anim = get_node("AnimatedSprite2D")

# func _ready():
#	anim.play('Idle')

# func _physics_process(delta):
	# Add the gravity.
#	if not is_on_floor():
#		velocity.y += gravity * delta

	# Handle Jump.
#	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
#		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
#	var direction = Input.get_axis("ui_left", "ui_right")
#	if direction:
#		velocity.x = direction * SPEED
#		anim.play('Float')
#	else:
#		anim.play('Idle')
#		velocity.x = move_toward(velocity.x, 0, SPEED)

#	move_and_slide()
