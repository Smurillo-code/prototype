extends CharacterBody3D

# Adding Animations
# ------------------------------------------------
# 1. Define Animations: Create new animations in Godot's animation tools.
# 2. Add Animation Nodes: Ensure 'AnimationPlayer' nodes exist for animated objects.
# 3. Update Parts Dictionary: In `_ready`, add new nodes to 'parts' dict, e.g., `"anim_player": $AnimationPlayer`.
# 4. Create Animation Methods: Write methods for new animations, e.g., `func perform_attack() -> void`.
# 5. Implement Animation Logic: In the methods, use `parts["anim_player"].play("your_animation_name")` to play animations.
# 6. Integrate with Existing Code: Add logic to trigger these animations (e.g., in `_input` or `_process` functions).
# 7. Test Animations: Ensure animations work as expected and integrate smoothly.
# 8. Optimize and Refine: Adjust timings, transitions, or other elements for best results.
#
# Example for Adding an Attack Animation:
# @onready var parts: Dictionary = {"head": $head, "body": $body, "anim_player": $AnimationPlayer, ...}
# func perform_attack() -> void: parts["anim_player"].play("attack_animation")
# func _input(event: InputEvent) -> void: if event is InputEventKey and event.pressed: perform_attack()
#
# Adjust steps based on your specific game needs and scenarios.


# Exported Variables
@export var sprint_enabled: bool = true
@export var crouch_enabled: bool = true
@export var base_speed: float = 6.0
@export var sprint_speed: float = 10.0
@export var jump_velocity: float = 5.0
@export var sensitivity: float = 0.1
@export var accel: float = 10.0
@export var crouch_speed: float = 3.0
@export var dash_speed: float = 12.0;
@export var dash_duration: float = 5.0;
@export var dash_cooldown: float = 2.0;

# Member Variables
var speed: float = base_speed
var state: String = "normal"  # normal, sprinting, crouching
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_fov_extents: Array[float] = [75.0, 85.0]  # index 0 is normal, index 1 is sprinting
var base_player_y_scale: float = 1.0
var crouch_player_y_scale: float = 0.75
#dashing
var dashing: bool = false
var dash_locked:bool = false
#grappling
var grappling = false
var hookpoint = Vector3()
var hookpoint_get = false;

# Node References
@onready var parts: Dictionary = {
	"head": $head,
	"camera": $head/camera,
	"camera_animation": $head/camera/camera_animation,
	"body": $body,
	"collision": $collision,
}
@onready var world: SceneTree = get_tree()

func _ready() -> void:
	parts["camera"].current = true

func _process(delta: float) -> void:
	dash_cooldown = dash_cooldown + 0.05
	handle_movement_input(delta)
	update_camera(delta)

func _physics_process(delta: float) -> void:

	parts.camera_animation.speed_scale = 0;
	apply_gravity(delta)
	handle_jump()
	move_character(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		handle_mouse_movement(event)

# Movement Logic
func handle_movement_input(delta: float) -> void:
	if Input.is_action_pressed("move_sprint") and !Input.is_action_pressed("move_crouch") and !Input.is_action_pressed("dash") and sprint_enabled and !dashing:
		enter_sprint_state(delta)
	elif Input.is_action_pressed("move_crouch") and !Input.is_action_pressed("move_sprint") and !Input.is_action_pressed("dash") and sprint_enabled and !dashing:
		enter_crouch_state(delta)
	elif Input.is_action_pressed("dash") and is_on_floor() and !Input.is_action_pressed("move_crouch") and !Input.is_action_pressed("move_sprint") and !dashing and dash_cooldown >= 2.0:
		enter_dash_state(delta) 
	else:
		if !dashing:
			enter_normal_state(delta)

func enter_sprint_state(delta: float) -> void:
	state = "sprinting"
	speed = sprint_speed
	parts["camera"].fov = lerp(parts["camera"].fov, camera_fov_extents[1], 10 * delta)

func enter_crouch_state(delta: float) -> void:
	state = "crouching"
	speed = crouch_speed
	apply_crouch_transform(delta)

func enter_dash_state(delta: float) -> void:
	state = "dashing"
	speed = dash_speed
	dashing = true
	parts["camera"].fov = lerp(parts["camera"].fov, camera_fov_extents[1], 10 * delta)

func enter_normal_state(delta: float) -> void:
	state = "normal"
	speed = base_speed
	reset_transforms(delta)

# Camera Logic
func update_camera(delta: float) -> void:
	match state:
		"sprinting":
			parts["camera"].fov = lerp(parts["camera"].fov, camera_fov_extents[1], 10 * delta)
		"dashing":
			if(!dash_locked):
				parts["camera"].fov = lerp(parts["camera"].fov, camera_fov_extents[1], 10 * delta)
		"normal":
			parts["camera"].fov = lerp(parts["camera"].fov, camera_fov_extents[0], 10 * delta)

# Animation Logic
func apply_crouch_transform(delta: float) -> void:
	parts["body"].scale.y = lerp(parts["body"].scale.y, crouch_player_y_scale, 10 * delta)
	parts["collision"].scale.y = lerp(parts["collision"].scale.y, crouch_player_y_scale, 10 * delta)

func reset_transforms(delta: float) -> void:
	parts["body"].scale.y = lerp(parts["body"].scale.y, base_player_y_scale, 10 * delta)
	parts["collision"].scale.y = lerp(parts["collision"].scale.y, base_player_y_scale, 10 * delta)

# Physics Logic
func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

func handle_jump() -> void:
	if Input.is_action_pressed("move_jump") and is_on_floor():
		velocity.y += jump_velocity	

func move_character(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector2 = input_dir.normalized().rotated(-parts["head"].rotation.y)
	if is_on_floor() and !dashing:
		accel = 10
		gravity = 12
		velocity.x = lerp(velocity.x, direction.x * speed, accel * delta)
		velocity.z = lerp(velocity.z, direction.y * speed, accel * delta)
	elif dashing:
		dash_cooldown = 0
		if direction == Vector2.ZERO:
			velocity.x = lerp(velocity.x, direction.x * speed, accel * delta)
			velocity.z = lerp(velocity.z, direction.y * speed, accel * delta)
			dash_locked = true
			parts["camera"].fov = lerp(parts["camera"].fov, camera_fov_extents[0], 10 * delta)
		else:
			if(!dash_locked):
				velocity.x = direction.x * speed
				velocity.z = direction.y * speed
		dash_duration = dash_duration - 0.1
		if(dash_duration <= 0):
			dashing = false
			dash_locked = false
			dash_duration = 5.0
	else:
		accel = 5
		gravity = gravity + gravity*0.01
		velocity.x = lerp(velocity.x, direction.x * speed, accel * delta * 2) 
		velocity.z = lerp(velocity.z, direction.y * speed, accel * delta * 2)
	if direction != Vector2.ZERO and !dashing:
		parts.camera_animation.speed_scale = 1;
	move_and_slide()

# Input Handling
func handle_mouse_movement(event: InputEventMouseMotion) -> void:
	if !world.paused:
		parts["head"].rotation_degrees.y -= event.relative.x * sensitivity
		parts["head"].rotation_degrees.x -= event.relative.y * sensitivity
		parts["head"].rotation.x = clamp(parts["head"].rotation.x, deg_to_rad(-90), deg_to_rad(90))
