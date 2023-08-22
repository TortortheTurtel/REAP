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
# if true, the next time the player dash brakes, a jump is immediately called.

# if true, the next time the player hits the ground, they instantly dashbrake towards the direction they initially indentented
# will be using the same timer as 


func _unhandled_input(event):
	# needs ui that checks what inputs you did and the results that came from it
	# only for debugging...
#	if event.is_pressed():
#		print(event.as_text())
#	if event.is_action_released( "jump") or event.is_action_released( "ui_up") or event.is_action_released("ui_down"):
#		print(event.as_text() + "R")

	if Input.is_action_just_pressed("jump"):
		# currently bugged, since these parameters are dependent on the player's input rather than where they are facing,
		# they can do both gallop jump and normal jump if they look towards the opposite of their velocity, jump queue while holding forward
		# adds jump queueing to when you dashbrake, and press jump, the next dash brake will instantly make you jump? seems like a good way to make the tech consistent.
		# make it so that if a jump queue is called, and a brake dash is to happen upon landing, cancel gallop and just convert it into a queue_jump_brake
		# This is to remove the times when a backward gallop happens instead of a normal brake dash as intended
		# If they want to do a backward gallop, then they have to do a jump release input before hitting the ground (not yet implemented), or after it instead of dashing
		# To be added: super jump - Convert Horizontal momentum to upward momentum 
		# & Kicking... - way to transfer momentum from one object to another or change its direction when hitting a wall/enemy (description in discord)
		# sounds - just as a way to make the game feel
		
		if place_state == GROUNDED:
			if !can_gallop_jump:
				jump()
			else:
				queue_jump_brake = true #the next brake dash will have a brake jump.
		
		if place_state == AIRBOURNE:
			if can_brakeboost:
				queue_brake_boost_while_air = true
			else:
				queue_jump = true
			JumpQueue.start()
	
	if Input.is_action_just_released("jump"):
		
		queue_jump_brake = false
		#this will be potentially be abused during a pause, where the player will release their keyboard input to avoid this, better watch out
		if can_gallop_jump == true and place_state == GROUNDED:
			brake_jump()
	
	
	input_vector.x = ceil(Input.get_action_strength("ui_right")) - ceil(Input.get_action_strength("ui_left"))
	input_vector.y = ceil(Input.get_action_strength("ui_down")) - ceil(Input.get_action_strength("ui_up"))
	
	var input_sum = Vector2( ceil(Input.get_action_strength("ui_left")) + ceil(Input.get_action_strength("ui_right")) , ceil(Input.get_action_strength("ui_up")) + ceil(Input.get_action_strength("ui_down")) )
	wish_to_brake = false
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
	
	if Input.is_action_just_pressed("aim"):
		cam_state = AIMMING
		camera.smoothing_enabled = false
		aim_zoom = camera.zoom
	if Input.is_action_just_released("aim"):
		aim_release()
		camera.smoothing_enabled = true
		cam_state = LOOKING
	
	match cam_state:
		LOOKING:
			look(event)
		AIMMING:
			aim(event)

var aim_zoom = Vector2(1,1)

func _physics_process(delta):
	velocity_magnitude = velocity.distance_to(Vector2.ZERO)
	#will be optimizing this in the future so that certain codes only present under certain conditions
	sudden_input_change()
	detect_brake_boost()
	label.text = str(velocity_magnitude)
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

onready var jump_velocity = (2 * JUMP_HEIGHT) / JUMP_PEAK_TIME
#this will be changed in the future to use value as actual gravity
onready var GRAVITY       = (-2.0 * JUMP_HEIGHT) / (JUMP_PEAK_TIME * JUMP_PEAK_TIME)

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
onready var JumpQueue = get_node("Node2D/JumpQueue")

func upDown_physics(delta):
#	#air friction already handled in Match place_state but it only affects horizontals
	player_z_pos += z_velocity * delta + (0.5 * GRAVITY * delta * delta)
	player_z_pos = clamp(player_z_pos, floor_z_pos, 100000)
	if player_z_pos > floor_z_pos: 
		place_state = AIRBOURNE
	else:
		place_state = GROUNDED
	
	z_velocity += GRAVITY * delta
	
	if place_state == GROUNDED:
		z_velocity = 0
		if queue_jump: 
			jump()
			queue_jump = false
	
	
	# this will have to be done in a dif place, deffo
	get_node("Sprite").scale = Vector2(1,1) * (1 + (0.005 * (player_z_pos))) # have this min to zero in the future, for falling fx
	
	
	crossHair.scale = camera.zoom * DEFAULT_CROSSHAIR_SCALE
	if cam_state != AIMMING:
		# make this have smoothing in the future, it has hard transition currently
		camera.position.y = camera.zoom.y * DEFAULT_CAMERA_Y_POSITION
		camera.zoom = player_selected_zoom * (1 + (0.005 * (player_z_pos))) # have this move up down to make sure that player is always same pos relative to camera
	else:
		camera.zoom = aim_zoom

func jump():
	z_velocity = jump_velocity

func brake_jump():
	z_velocity = jump_velocity * 0.5


var can_gallop_jump = false
var queue_jump_brake = false
func _on_JumpBuffer_timeout():
	queue_jump_brake = false 
	can_gallop_jump = false 

var queue_brake_boost_while_air = false
var queue_jump = false
func _on_JumpQueue_timeout():
	queue_brake_boost_while_air = false
	queue_jump = false

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
	
	if can_brakeboost and (wish_to_brake or queue_brake_boost_while_air):
		velocity = -(velocity * 0.95 +  (acceleration * delta) - brake_boost_power) # this is a brake
		can_gallop_jump = true
		JumpBuffer.start() #this will make it so that if spacebar was released during this time, a brake_jump will happen.
		if queue_jump_brake:
			brake_jump()
			queue_jump_brake = false
		if queue_brake_boost_while_air:
			queue_jump_brake = true
		queue_brake_boost_while_air = false
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
		#will be restructured to use less velocity maggitudes and sin cos shit, still no idea how to do that rn tho
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
		# currently not working as intended
		
		sudden_input_change_factor = (velocity.normalized().dot(wishDirection) + 1) * 0.5
		
	else:
		sudden_input_change_factor = 1

var brake_boost_power = Vector2.ZERO
# using player velocity and dot product of wishdir and velocity
var can_brakeboost = false
#  % of velocity that player needs to be at before being able to gallop
# will be lowered by a lot when in air
export var GALLOP_DETECT_FACTOR = 0.4


func detect_brake_boost():
	# this might also detect future sudden changes in velocity like getting hit as a brake boost, better fix this.
	# will be changed in the future to not use magnitude
	if velocity_magnitude > (TOP_WALKING_SPEED * GALLOP_DETECT_FACTOR) and sudden_input_change_factor < 0.45:# this  number is the allowance of direction shift, higher number the more allowance, max of 1, will not be user adjustable value
		# for allowance of direction shift 0 means opposite, 0.5 means left and right, 1 means forward
		brake_boost_power = wishDirection * 700
		can_brakeboost = true
	else:
		can_brakeboost = false 

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
		# make it so that when player selected zoom is higher, then the damping on the camera is also higher

var aim_change = Vector2.ZERO
func aim(event):
	#note aim only rotates the sprite, not the player, so keep that in mind
	#has a bug where if the camera is centered on a rich text label, it stops moving
	
	get_node("Sprite").look_at(camera.global_position)
	get_node("Sprite").rotation += PI/2 # don't use this, rotate the sprite itself instead, dummy
	if event is InputEventMouseMotion:
		#this needs to take into account the x movement of mouse, cause it only affects the zoom
		aim_change += Vector2(1,1) * ( (0.002 * (-event.relative.y)))
		camera.position += event.relative * 0.5

func aim_release():
	camera.position = Vector2(0,-250)
	#enable this line vvv of code to make the camera return with the same rotation as sprite 
	rotation = get_node("Sprite").global_rotation
	get_node("Sprite").rotation = 0
	player_selected_zoom += aim_change
	aim_change = Vector2.ZERO












