extends KinematicBody2D





#in liquid will not be included for simplicity sake
var place_state = GROUNDED

enum {
	GROUNDED,
	AIRBOURNE
}

var cam_state = LOOKING
onready var camera = $Camera2D
onready var crossHair = $Camera2D/crosshair
onready var collisionshape = $CollisionShape2D
onready var label = $Label

var player_selected_zoom = Vector2(1,1)
export var DEFAULT_CAMERA_Y_POSITION = -250
export var DEFAULT_CROSSHAIR_SCALE = Vector2(0.1,0.1)

#SI UNITS: cm s^-1
export var TOP_WALKING_SPEED = 420
#SI UNITS: s
export var TIME_TO_TOP_WALKING_SPEED = 0.1

#still under development this one
var top_gallop_speed_to_walking_ratio = 3.5
var time_to_top_gallop_speed = 4

var char_force = Vector2.ZERO
#this will determine the char's max speed
#SI UNITS: kg m s^-2 * 100cm m^-1
onready var char_force_max = TOP_WALKING_SPEED * ((GRAVITY_HORIZONTAL * GROUND_FRICTION_COEFFICIENT) + (AIR_DRAG_COEFFECIENT * TOP_WALKING_SPEED * TOP_WALKING_SPEED))
#SI UNITS: char_force_max s^-1
onready var char_force_per_second = char_force_max / (TIME_TO_TOP_WALKING_SPEED)
# this is in kilograms, 1 godot unit = 1 cm
export var CHAR_MASS = 100
#SI UNITS: cms^ -2
export var GRAVITY_HORIZONTAL = 980.665
#this will be dependent on the tile
#this will be removed

#dependent on the location
export var GROUND_FRICTION_COEFFICIENT = 0.9
onready var ground_friction_force = GROUND_FRICTION_COEFFICIENT * CHAR_MASS * GRAVITY_HORIZONTAL

#dependent on the character's state. ei airbourne, jordans got crinkled, etc. etc., amount of friction from ground that can be used
#0.88 for average, 0.33 for EX when he is facing forward
var character_traction = 1

#will be implementing 
export var AIR_DRAG_COEFFECIENT = 0.00001

onready var air_resistance_force = 0 

var velocity = Vector2.ZERO
var acceleration = Vector2.ZERO
var Ground_friction_force = Vector2.ZERO

enum{
	LOOKING,
	AIMMING
}

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	#Engine.set_target_fps(15) #in the future, disable camera smoothing at low fps values
	camera.position.y = DEFAULT_CAMERA_Y_POSITION
	pass 

var input_vector = Vector2.ZERO
var prevInput_vector = Vector2.ZERO
var input_conflict = Vector2.ZERO
var prevInput_conflict = Vector2.ZERO

func _unhandled_input(event):
	#put more of the things into here
	#if Input.is_action_pressed("jump"):
	#	place_state = AIRBOURNE
	#if Input.is_action_just_released("jump"):
	#	place_state = GROUNDED
	
	#maybe make it so that jumping dependent on current velocity? the faster the player currently is the lower their jump??
	# i dunno, seems kinda counter intuitive, but its the only hope for galloping to exist lol
	# currently jumping feels too short and quick, which works for galloping, but not for normal jumping
	# detect when player is brakedash, to perform a gallopjump, default jump always the same no matter what speed
	# add a bit of delay when brake dash
	if Input.is_action_just_pressed("jump") and place_state == GROUNDED:
		
		if can_gallop_jump == false:
			z_velocity = jump_velocity 
	
	if Input.is_action_just_released("jump") and can_gallop_jump == true and place_state == GROUNDED:
		z_velocity = jump_velocity * 0.5
	
	
	wish_to_brake = false
	input_vector.x = ceil(Input.get_action_strength("ui_right")) - ceil(Input.get_action_strength("ui_left"))
	input_vector.y = ceil(Input.get_action_strength("ui_down")) - ceil(Input.get_action_strength("ui_up"))
	
	var input_sum = Vector2( ceil(Input.get_action_strength("ui_left")) + ceil(Input.get_action_strength("ui_right")) , ceil(Input.get_action_strength("ui_up")) + ceil(Input.get_action_strength("ui_down")) )
	
	# Check for when prevInput, and new button being pressed that caused the conflict 
	if  input_sum.x  == 2:
		input_conflict.x = 1
		input_vector.x = -prevInput_vector.x
		
	elif input_sum.x == 1:
		input_conflict.x = 0
		if prevInput_vector.x != input_vector.x:
			wish_to_brake = true
		prevInput_vector.x = input_vector.x
	

	
	if  input_sum.y  == 2:
		input_conflict.y =  1
		input_vector.y = -prevInput_vector.y
		
	elif input_sum.y == 1:
		input_conflict.y = 0
		if prevInput_vector.y != input_vector.y:
			wish_to_brake = true
		prevInput_vector.y = input_vector.y
	
	print(input_vector)
	
	
	
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




func _physics_process(delta):
	velocity_magnitude = velocity.distance_to(Vector2.ZERO)
	#will be optimizing this in the future so that certain codes only present under certain conditions
	sudden_input_change()
	detect_brake_boost()
	
	wishdir(input_vector)
	upDown_physics(delta)
	match place_state:
		GROUNDED:
			character_traction = 1 #this will  be dependent on area in the future
			move(delta)
		AIRBOURNE:
			character_traction = 0.001
			air_move(delta)
	

#will be changing this in the future to have have gravity be consistent with character and game measurements
export var JUMP_HEIGHT    = 80.0
export var JUMP_PEAK_TIME = 0.72/2 #default 0.36/2

onready var jump_velocity = (2*JUMP_HEIGHT) / JUMP_PEAK_TIME
#this will be changed in the future to use value as actual gravity
onready var GRAVITY       = (-2.0 *JUMP_HEIGHT) / (JUMP_PEAK_TIME * JUMP_PEAK_TIME)

var wish_to_brake = false
#move this to a lower position in the future
var player_z_pos  = 0
var player_height = 80
var floor_z_pos   = 0 #this will be dependent on area in the future

var z_velocity     = 0
var z_acceleration = 0
var jump_force     = 0
var step_size      = 20 
onready var JumpBuffer = get_node("Node2D/JumpBuffer")

func upDown_physics(delta):
#	#air friction already handled in Match place_state
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
	
	
	
	# this will have to be done in a dif place, deffo
	# maybe it should be based more on player sprite rather than player_z_pos
	get_node("Sprite").scale = Vector2(1,1) * (1+ (0.005 * (player_z_pos))) # have this min to zero in the future, for falling fx
	camera.zoom = player_selected_zoom * (1+ (0.005 * (player_z_pos))) # have this move up down to make sure that player is always same pos relative to camera
	crossHair.scale = camera.zoom * DEFAULT_CROSSHAIR_SCALE
	if cam_state != AIMMING:
		camera.position.y = camera.zoom.y * DEFAULT_CAMERA_Y_POSITION
	
	

var can_gallop_jump = false

func _on_JumpBuffer_timeout():
	can_gallop_jump = false



func move(delta):
	if input_vector != Vector2.ZERO:
		char_force *= sudden_input_change_factor
		char_force = char_force.move_toward(char_force_max * wishDirection, char_force_per_second * delta)# * sudden_input_change_factor
		
	else:
		char_force = Vector2.ZERO
	
	#This is temporary, will likely be replaced with something more convuluted and makes sense with the wind shit
	air_resistance_force = AIR_DRAG_COEFFECIENT * velocity * velocity * velocity 
	
	Ground_friction_force = ground_friction_force * velocity * 0.01
	acceleration = ((char_force * character_traction ) - Ground_friction_force - air_resistance_force)/ CHAR_MASS #my magnum opos
	
#	#BRAKE BOOST
	if can_brakeboost and wish_to_brake:
		velocity = -(velocity * .2) + brake_boost_power + (acceleration * delta)
		print( "A")
	else:
		velocity += acceleration * delta
	
	
	for i in get_slide_count():
		var collision = get_slide_collision(i)
		if collision.collider is MoveableBlock:
			#have this set the char force temporarily to zero, but kill it all on the next frame
			impulse = 2 * collision.collider.mass * (collision.collider.get_linear_velocity() - prev_tick_velocity) / (CHAR_MASS + collision.collider.mass)
			collision.collider.apply_impulse(position - (collisionshape.shape.radius * collision.normal) - collision.collider.position,  -impulse +(acceleration * CHAR_MASS * delta))
			# this is to reduce the impact of kinetic to rigid collision wherein the kinetic body just stops moving
#			velocity -= (collision.normal / collision.collider.mass)
	
	
	prev_tick_velocity = velocity
	velocity = move_and_slide(velocity, Vector2.ZERO, false, 4, PI/4, false)
var impulse = 0
var prev_tick_velocity = 0

#instructions at https://www.desmos.com/calculator/9eavursizr
export var AIR_CONTROL_FACTOR = 0.01 #how much % of the velocity the player can control per tick
export var AIR_CONTROL_SPEED_LOSS = 1 # only applies when turning, not all the time. only affects % of velocity lost from clipping

var velocity_magnitude = 0
var air_control_ellipse = Vector2.ZERO
var air_control_ellipse_rotated = Vector2.ZERO

func air_move(delta):
	#friction factor here is set to something else at physics
	char_force = Vector2.ZERO
	air_resistance_force = AIR_DRAG_COEFFECIENT * velocity * velocity * velocity
	acceleration = ((char_force * wishDirection * character_traction ) - air_resistance_force)/ CHAR_MASS
	
	velocity += velocity.normalized() * acceleration * delta
	
	if input_vector != Vector2.ZERO:
		#this will only be updated here since this is the only place that currently uses it
		
		velocity *= (1-AIR_CONTROL_FACTOR)# clip velocity to be added again later
		
		#an ellipse that is the same size as the velocity lost from clipping, and whose width is the furthest point it can touch the circle
		#instructions at https://www.desmos.com/calculator/9eavursizr
		#will be restructured to use less velocity maggitudes and sin cos shit, still no idea how to use it rn tho
		var wish_direction_air_control = wishDirection.angle() - velocity.angle()
		air_control_ellipse.x = AIR_CONTROL_FACTOR * velocity_magnitude * cos(wish_direction_air_control)
		air_control_ellipse.y = AIR_CONTROL_SPEED_LOSS  * sin(wish_direction_air_control ) *  sqrt(pow(velocity_magnitude,2) - pow((velocity_magnitude * ( 1-AIR_CONTROL_FACTOR ) ),2))
		
		if air_control_ellipse.distance_to(Vector2.ZERO) <= 8:
			air_control_ellipse.x = 8 * cos(wish_direction_air_control)
			air_control_ellipse.y = 8 * sin(wish_direction_air_control)
		
		velocity += air_control_ellipse.rotated( velocity.angle())
	
	#print(str(velocity.distance_to(Vector2.ZERO)))
	
	velocity = move_and_slide(velocity, Vector2.ZERO)

var sudden_input_change_factor = 1

func sudden_input_change():
	if velocity_magnitude >= 1:
		
		#this is used to reset the char_force back to zero depending on how different the input is from the current velocity
		# currently not working
		sudden_input_change_factor = (velocity.normalized().dot(wishDirection) + 1) * 0.5
		
	else:
		sudden_input_change_factor = 1

var brake_boost_power = Vector2.ZERO
var can_brakeboost = false
#  % of velocity that player needs to be at before being able to gallop
# will be lowered by a lot when in air
export var GALLOP_DETECT_FACTOR = 0.4


func detect_brake_boost():
	
	# will be changed in the future to not use magnitude
	if velocity_magnitude > (TOP_WALKING_SPEED * GALLOP_DETECT_FACTOR) and sudden_input_change_factor < 0.45:# this  number is the allowance of direction shift, higher number the more allowance, max of 1, will not be user adjustable value
		# for allowance of direction shift 0 means opposite, 0.5 means left and right, 1 means forward
		brake_boost_power = wishDirection * 800
		can_gallop_jump = true
		can_brakeboost = true
		JumpBuffer.start()
	else:
		can_brakeboost = false 


#func inputvector():
#	#perhaps ill have to move this into _unhandled input but im too tired for now so ill do that tommorow lol
#	input_vector = Vector2.ZERO
#
#	x_input()
#	y_input()
##	print(input_vector) #PLEASE TEST THIS! I am unsure about how it works my keyboard does not allow for more that 3 inputs at once
#
#	# this is a way for players to be able to switch directions without activating brake boost
#	# Checks when there is a conflict, when a and d are pressed at the same time, input_vector(0,0)
#	# all good now, only prob is with releasing which could be use to make galloping easier but eh
#
#func x_input():
#	input_vector.x = (ceil(Input.get_action_strength("ui_right")) - ceil(Input.get_action_strength("ui_left")))
#	# Check for when prevInput, and new button being pressed that caused the conflict 
#	if prevInput_vector.x != 0 and ceil(Input.get_action_strength("ui_left")) + ceil(Input.get_action_strength("ui_right")) == 2:
#		input_conflict.x = 1
#		wish_to_brake = false
#
#		input_vector.x = -prevInput_vector.x
#	else:
#		input_conflict.x = 0
#		prevInput_vector.x = input_vector.x
#
#
#
#func y_input():
#	input_vector.y = (ceil(Input.get_action_strength("ui_down"))- ceil(Input.get_action_strength("ui_up")))
#
#	if prevInput_vector.y != 0 and ceil(Input.get_action_strength("ui_up")) + ceil(Input.get_action_strength("ui_down")) == 2:
#		input_conflict.y =  1
#		wish_to_brake = false
#		input_vector.y = -prevInput_vector.y
#	else:
#		input_conflict.y = 0
#		prevInput_vector.y = input_vector.y
#
#
#

var  wishDirection = Vector2.ZERO

func wishdir(vector2):
	wishDirection = Vector2.ZERO
	if vector2 != Vector2.ZERO:
		# the value this gives is already normalized, nice!
		wishDirection = Vector2(cos(rotation + vector2.angle()), sin(rotation + vector2.angle()))

func look(event):
	if event is InputEventMouseMotion:
		rotation += event.relative.x * 0.002 #this float is meant to represent sensitivity, prob make a value for that in tha future
		player_selected_zoom += Vector2(1,1) * ( (0.002 * (-event.relative.y)))# zoom in an out based on up down movement of mouse

var aim_change = Vector2.ZERO
func aim(event):
	#note aim only rotates the sprite, not the player, so keep that in mind
	#has a bug where if the camera is centered on a rich text label, it stops moving

	get_node("Sprite").look_at(camera.global_position)
	get_node("Sprite").rotation += PI/2
	if event is InputEventMouseMotion:
#		aim_change += Vector2(1,1) * ( (0.002 * (-event.relative.y)))
		#this is how aimming is handled
		camera.position += event.relative * 0.5

func aim_release():
	camera.position = Vector2(0,-250)
	#enable this line vvv of code to make the camera return with the same rotation as sprite 
	rotation = get_node("Sprite").global_rotation
	get_node("Sprite").rotation = 0
#	player_selected_zoom += aim_change
#	aim_change = Vector2.ZERO
	#make camera return to normal

