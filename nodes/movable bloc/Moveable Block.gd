extends RigidBody2D
class_name MoveableBlock

#!!!This will be implemented later on, using linear damp as an alternative for now!!!
var material_type = "wood"

#this will be dependent on area and z_position in the future
#concrete to wood surface KINETIC_FRICTION_COEFFIECIENT
export var KINETIC_FRICTION_COEFFIECIENT = .85
const GRAVITY = 980.665 # SI units : kg cm s^-2

var kinetic_friction = KINETIC_FRICTION_COEFFIECIENT * mass * GRAVITY
export var STATIC_FRICTION_COEFFIECIENT = 1
#always higher than kinetic friction
#https://www.engineersedge.com/coeffients_of_friction.htm <- site for static friction shit
var static_friction = STATIC_FRICTION_COEFFIECIENT * mass * GRAVITY

var friction_box = static_friction
var velocity = Vector2.ZERO


#friction here is for floor to object friction, built-in friction is for wall to object.
# warning-ignore:unused_argument
func _integrate_forces(state):
	#if box is not moving atleast above 10cm/s in any direction, then use static friction
	if get_linear_velocity().distance_to(Vector2.ZERO) <= 10:
		velocity = get_linear_velocity().move_toward(Vector2.ZERO, static_friction)
	else:
		velocity = get_linear_velocity().move_toward(Vector2.ZERO, kinetic_friction)

	set_linear_velocity(velocity)



