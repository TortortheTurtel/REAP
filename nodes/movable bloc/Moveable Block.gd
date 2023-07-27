extends RigidBody2D
class_name MoveableBlock

#this will be dependent on area and z_position in the future
#export var kin_friction = 10
#export var static_friction = 20
#var friction_box = static_friction
#var velocity = Vector2.ZERO
#
#
#
## warning-ignore:unused_argument
#func _integrate_forces(state):
#	if velocity == Vector2.ZERO:
#		friction_box = static_friction
#	else:
#		friction_box = kin_friction
#
#	velocity = get_linear_velocity().move_toward(Vector2.ZERO, friction_box)
#	set_linear_velocity(velocity)

