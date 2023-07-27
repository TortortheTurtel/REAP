extends KinematicBody2D

var CHAR_FORCE = 0
var char_force_max = 3700
#delta adjusted already
var char_force_per_frame = 1000
const CHAR_MASS = .5
const WORLD_FRICTION = 100
var char_friction_factor = 1

#this value is manually obtained by going to the move(delta) func, read instructions there
var vel_max = 300


const passive_friction =  70
const ground_friction = 5
var friction_factor = 1

var velocity = Vector2.ZERO
var acceleration = 0
var drag_coeffecient = 0


#in liquid will not be included for simplicity sake
var place_state = GROUNDED
enum {
	GROUNDED,
	AIRBOURNE
}

var cam_state = LOOKING
onready var camera = $Camera2D
onready var CrossHair = $Camera2D/crosshair
var player_selected_zoom = Vector2(1,1)
export var DEFAULT_CAMERA_Y_POSITION = -250
export var DEFAULT_CROSSHAIR_SCALE = Vector2(0.1,0.1)

enum{
	LOOKING,
	AIMMING
}
onready var label = $Label
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	#Engine.set_target_fps(15) #in the future, disable camera smoothing at low fps values
	camera.position.y = DEFAULT_CAMERA_Y_POSITION
	pass 

func _physics_process(delta):
	velocity_magnitude = velocity.distance_to(Vector2.ZERO)
#	print(get_local_mouse_position())
	detect_brake_boost()
	sudden_input_change_factor()
	inputvector()
	wishdir(input_vector)
	upDown_physics(delta)
	#print(velocity_magnitude)
	match place_state:
		GROUNDED:
			friction_factor = 1 #this will  be dependent on area in the future
			move(delta)
		AIRBOURNE:
			friction_factor = 0.001
			air_move(delta)

export var jump_height = 80.0
export var jump_peak_time = 0.72/2 #default 0.36/2

onready var jump_velocity = (2*jump_height) / jump_peak_time
onready var GRAVITY       = (-2.0 *jump_height) / (jump_peak_time * jump_peak_time)

var wish_to_brake = true
#move this to a lower position in the future
var player_z_pos = 0
var player_height = 80
var floor_z_pos = 0 #this will be dependent on area in the future

var z_velocity = 0
var z_acceleration = 0
var jump_force = 0
var step_size = 20 
onready var JumpBuffer = get_node("Node2D/JumpBuffer")

func upDown_physics(delta):
#	#air friction already handled in Match place_state
	#currently disabled for debugging purposes
	player_z_pos += z_velocity * delta + (0.5*GRAVITY*delta*delta)
	player_z_pos = clamp(player_z_pos, floor_z_pos, 100000)
	if player_z_pos > floor_z_pos: 
		place_state = AIRBOURNE
		#label.text = "Airbourne " + str(player_z_pos)
	else:
		place_state = GROUNDED
		#label.text = "Grounded"
	
	z_velocity += GRAVITY * delta
	
	if place_state == GROUNDED:
		z_velocity = 0
	
	#z_velocity += (jump_force / CHAR_MASS) * delta 
	
	
	# this will have to be done in a dif place, deffo
	# maybe it should be based more on player sprite rather than player_z_pos, welp, time to do school stuff
	# camera codesss (no im not gonna put this into a function)
	get_node("Sprite").scale = Vector2(1,1) * (1+ (0.005 * (player_z_pos))) # have this min to zero in the future, for falling fx
	camera.zoom = player_selected_zoom * (1+ (0.005 * (player_z_pos))) # have this move up down to make sure that player is always same pos relative to camera
	CrossHair.scale = camera.zoom * DEFAULT_CROSSHAIR_SCALE
	if cam_state != AIMMING:
		camera.position.y = camera.zoom.y * DEFAULT_CAMERA_Y_POSITION
	
	#more responsive and simpler way of jumping, but it doesnt allow for big jump
	#maybe make it so that jumping dependent on current velocity? the faster the player currently is the lower their jump??
	# i dunno, seems kinda counter intuitive, but its the only hope for galloping to exist lol
	# currently jumping feels too short and quick, which works for galloping, but not for normal jumping
	# detect when player is brakedash, to perform a gallopjump, default jump always the same no matter what speed
	# add a bit of delay when brake dash
	if Input.is_action_just_pressed("jump") and place_state == GROUNDED:
		
		if can_gallop_jump == false:
			z_velocity = jump_velocity 
	
	if Input.is_action_just_released("jump") and can_gallop_jump == true:
		z_velocity = jump_velocity * 0.5
			
	
	
	#this is here for debugging purposes
#	if Input.is_action_pressed("jump"):
#		player_z_pos = 30
#	if Input.is_action_just_released("jump"):
#		player_z_pos = 0

var can_gallop_jump = false

func _on_JumpBuffer_timeout():
	
	can_gallop_jump = false

#make this increase up to a point to smooth out pushing power
const PUSH = 500

func move(delta):
	
	#i should probably turn this into a function
	if input_vector != Vector2.ZERO:
		
		#the third value on the clamp determines max_force (subtract by speed to make it be truly reflective of max_speed
		CHAR_FORCE = clamp(CHAR_FORCE,0, char_force_max - char_force_per_frame) * sudden_input_change_factor()
		#this is the speed at which the character accelerates, better make a a var for the in the future
		CHAR_FORCE += char_force_per_frame * delta * 60
	else:
		CHAR_FORCE = 0
	
	#this is some physics stuff, i dont understand it anymore lol
	drag_coeffecient = ground_friction * velocity.distance_to(Vector2.ZERO) * friction_factor #this will make is to that acceleration doesnt get out of hand 
	acceleration = (CHAR_FORCE - drag_coeffecient) / CHAR_MASS #can reach negative values, so make sure to clamp
	
	#brake boosting stuff
	if can_brakeboost == true and wish_to_brake == true:
		velocity = -(velocity * .2) + brake_boost_power
	else:
		velocity += wishDirection * clamp(acceleration, 0, 10000000) * delta
	
	
	wish_to_brake = true
	
	velocity = velocity.move_toward( Vector2.ZERO , passive_friction * friction_factor)
	
#	velocity = move_and_slide(velocity, Vector2.ZERO)
	velocity = move_and_slide(velocity, Vector2.ZERO, false, 4, 0.785398, false)
	
	for i in get_slide_count():
		var collision = get_slide_collision(i)
#		print("Collided with: ", collision.collider.name)
		if collision.collider is MoveableBlock:
			collision.collider.apply_central_impulse(-collision.normal * PUSH)

	# print(str(velocity.distance_to(Vector2.ZERO)))
	# use this code to manually check what walking max walking speed is, this will be used for detect_break_boost()

#instructions at https://www.desmos.com/calculator/9eavursizr
export var air_control_factor = 0.01 #how much of the velocity the player can control per frame
export var air_control_speed_loss_export = 1 # only applies when turning, not all the time. only affects % of velocity lost from clipping
onready var air_control_speed_loss = air_control_speed_loss_export 

var velocity_magnitude = 0
var air_control_ellipse = Vector2.ZERO
var air_control_ellipse_rotated = Vector2.ZERO



func air_move(delta):
	#friction factor here is set to something else at physics
	CHAR_FORCE = 0
	drag_coeffecient = ground_friction * velocity.distance_to(Vector2.ZERO) * friction_factor
	acceleration = (CHAR_FORCE - drag_coeffecient) / CHAR_MASS
	velocity += velocity.normalized() * clamp(acceleration, 0, 10000000) * delta
	velocity = velocity.move_toward( Vector2.ZERO , passive_friction * delta * friction_factor * 60)
	
	#i should probably turn this into a function
#	if input_vector != Vector2.ZERO:
#
#		#the third value on the clamp determines max_force (subtract by speed to make it be truly reflective of max_speed
#		CHAR_FORCE = clamp(CHAR_FORCE,0, char_force_max - char_force_per_frame) * sudden_input_change_factor()
#		#this is the speed at which the character accelerates, better make a a var for the in the future
#		#CHAR_FORCE += char_force_per_frame * delta * 60
#	else:
#		CHAR_FORCE = 0
	
	if input_vector != Vector2.ZERO:
		#this will only be updated here since this is the only place that currently uses it
		
		velocity *= (1-air_control_factor)# clip velocity to be added again later
		
		#an ellipse that is the same size as the velocity lost from clipping, and whose width is the furthest point it can touch the circle
		var wish_direction_air_control = wishDirection.angle() - velocity.angle()
		air_control_ellipse.x = air_control_factor * velocity_magnitude * cos(wish_direction_air_control)
		air_control_ellipse.y = air_control_speed_loss  * sin(wish_direction_air_control ) *  sqrt(pow(velocity_magnitude,2) - pow((velocity_magnitude * ( 1-air_control_factor ) ),2))
		
		
		if air_control_ellipse.distance_to(Vector2.ZERO) <= 8:
			air_control_ellipse.x = 8 * cos(wish_direction_air_control)
			air_control_ellipse.y = 8 * sin(wish_direction_air_control)
		
		
		velocity += air_control_ellipse.rotated( velocity.angle())
	
	
	
	
	#print(str(velocity.distance_to(Vector2.ZERO)))
	
	velocity = move_and_slide(velocity, Vector2.ZERO)


func sudden_input_change_factor():
	if velocity != Vector2.ZERO:
		#may get called several times lol, dont turn it into a function
		#gets dot product, and makes it be a float between 0-1
		var sudden_input_change_factor = (((velocity.normalized().dot(wishDirection) + 1))) * .5
		return sudden_input_change_factor
	else:
		return 1

var brake_boost_power = Vector2.ZERO
var can_brakeboost = false

func detect_brake_boost():
	# The first value I got from getting the highest walking velocity, multiplying by .6, then squaring
	#get the highest walking velocity by allowing the #print at move, then recording the highest number in debug
	# second number is the allowance of direction shift, higher number the move allowance, max of 1, will not be user adjustable value
	
	if velocity.distance_squared_to(Vector2.ZERO) > 36864 and sudden_input_change_factor() < 0.45:
		brake_boost_power = wishDirection * 800
		can_gallop_jump = true
		can_brakeboost = true
		JumpBuffer.start()
	else:
		can_brakeboost = false

var input_vector = Vector2.ZERO
var prevInput_vector = Vector2.ZERO

func inputvector():
	input_vector = Vector2.ZERO
	x_input()
	y_input()
	# this is a way for players to be able to switch directions without activating brake boost
	# Checks when there is a conflict, when a and d are pressed at the same time, input_vector(0,0)
	# all good now, only prob is with releasing which could be use to make galloping easier but eh

func x_input():
	input_vector.x = (Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"))
	# Check for when prevInput, and new button being pressed that caused the conflict 
	if prevInput_vector.x != 0 and Input.get_action_strength("ui_left") + Input.get_action_strength("ui_right") == 2:
		wish_to_brake = false
		input_vector.x = -prevInput_vector.x
	else:
		prevInput_vector.x = input_vector.x

func y_input():
	input_vector.y = (Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up"))
	if prevInput_vector.y != 0 and Input.get_action_strength("ui_up") + Input.get_action_strength("ui_down") == 2:
		wish_to_brake = false
		input_vector.y = -prevInput_vector.y
	else:
		prevInput_vector.y = input_vector.y

var  wishDirection = Vector2.ZERO

func wishdir(vector2):
	
	
	wishDirection = Vector2.ZERO
	if vector2 != Vector2.ZERO:
		wishDirection = Vector2(cos(rotation + vector2.angle()), sin(rotation + vector2.angle()))
		
	
	#this is already normalized, turns out

func look(event):
	if event is InputEventMouseMotion:
		#this is how looking is handled
		rotation += event.relative.x * 0.002 #this float is meant to represent sensitivity, prob make a value for that in tha future
		#print(event.relative.y) #maybe make it so that inputs less than |30| dont get accepted
#		if abs(event.relative.y) <= 10:
#			event.relative.y = 0
		player_selected_zoom += Vector2(1,1) * ( (0.002 * (-event.relative.y)))# zoom in an out based on up down movement of mouse

func aim(event):
	#note aim only rotates the sprite, not the player, so keep that in mind
	#has a bug where if the camera is centered on a rich text label, it stops moving
	
	get_node("Sprite").look_at(camera.global_position)
	get_node("Sprite").rotation += PI/2
	if event is InputEventMouseMotion:
		#this is how aimming is handled
		camera.position += event.relative * 0.5

func aim_release():
	camera.position = Vector2(0,-250)
	#enable this line vvv of code to make the camera return with the same rotation as sprite 
	rotation = get_node("Sprite").global_rotation
	get_node("Sprite").rotation = 0
	
	#make camera return to normal

func _unhandled_input(event):
	#put more of the things into here
	#if Input.is_action_pressed("jump"):
	#	place_state = AIRBOURNE
	#if Input.is_action_just_released("jump"):
	#	place_state = GROUNDED
	
	if Input.is_action_just_pressed("aim"):
		cam_state = AIMMING
		camera.smoothing_enabled = false
	if Input.is_action_just_released("aim"):
		aim_release()
		camera.smoothing_enabled = true
		cam_state = LOOKING
	
	match cam_state:
		LOOKING:
			look(event)
		AIMMING:
			aim(event)
		
