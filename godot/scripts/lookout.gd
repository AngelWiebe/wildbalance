extends Camera3D

const Forest := preload("res://scripts/forest.gd")
const START_TARGET := Vector3(1.65, 0.95, -1.5)
const START_YAW := -0.25
const START_PITCH := 0.23
const START_DISTANCE := 10.8

var target := START_TARGET
var yaw := START_YAW
var pitch := START_PITCH
var distance := START_DISTANCE
var zoom := START_DISTANCE
var following_deer := false
var free_fly := false
var fly_speed := 9.0
var controls_enabled := true


func _ready() -> void:
	_update_view()


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled


func _process(delta: float) -> void:
	if not controls_enabled:
		return

	if free_fly:
		_update_free_fly(delta)
		return

	var movement := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if not movement.is_zero_approx():
		following_deer = false

	if following_deer:
		var deer := get_parent().call("get_first_deer") as Node3D
		if is_instance_valid(deer):
			var desired_target := deer.position + Vector3.UP * 0.85
			target = target.lerp(desired_target, 1.0 - exp(-3.5 * delta))
		else:
			following_deer = false

	if not movement.is_zero_approx():
		var horizontal := Vector3(movement.x, 0, movement.y).normalized().rotated(Vector3.UP, yaw)
		target += horizontal * delta * (3.5 + distance * 0.2)
		target.x = clampf(target.x, -52.0, 36.0)
		target.z = clampf(target.z, -48.0, 44.0)
	distance = lerpf(distance, zoom, 1.0 - exp(-12.0 * delta))
	_update_view()


func _update_free_fly(delta: float) -> void:
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw)).normalized()
	var right := Vector3(cos(yaw), 0.0, -sin(yaw)).normalized()
	var movement := Vector3.ZERO

	if Input.is_physical_key_pressed(KEY_W):
		movement += forward
	if Input.is_physical_key_pressed(KEY_S):
		movement -= forward
	if Input.is_physical_key_pressed(KEY_D):
		movement += right
	if Input.is_physical_key_pressed(KEY_A):
		movement -= right
	if Input.is_physical_key_pressed(KEY_SPACE):
		movement.y += 1.0
	if Input.is_physical_key_pressed(KEY_SHIFT):
		movement.y -= 1.0

	if not movement.is_zero_approx():
		position += movement.normalized() * fly_speed * delta

	position.x = clampf(position.x, -60.0, 50.0)
	position.z = clampf(position.z, -56.0, 52.0)
	position.y = maxf(position.y, Forest.ground_height(position.x, position.z) + 0.80)

	var look_direction := Vector3(
		-sin(yaw) * cos(pitch),
		-sin(pitch),
		-cos(yaw) * cos(pitch)
	)
	look_at(position + look_direction)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return

	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		following_deer = false
		yaw -= event.relative.x * 0.004
		pitch = clampf(pitch + event.relative.y * 0.003, 0.10, 1.25)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if free_fly:
					fly_speed = minf(30.0, fly_speed * 1.2)
				else:
					zoom = maxf(2.8, zoom * 0.87)
			MOUSE_BUTTON_WHEEL_DOWN:
				if free_fly:
					fly_speed = maxf(2.0, fly_speed / 1.2)
				else:
					zoom = minf(34.0, zoom / 0.87)
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		free_fly = not free_fly
		following_deer = false

		if not free_fly:
			var forward := Vector3(-sin(yaw), -sin(pitch), -cos(yaw))
			target = position + forward.normalized() * distance
			_update_view()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		following_deer = not following_deer
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		following_deer = false
		free_fly = false
		target = START_TARGET
		yaw = START_YAW
		pitch = START_PITCH
		distance = START_DISTANCE
		zoom = START_DISTANCE


func _update_view() -> void:
	target.y = maxf(0.95, 1.10 + Forest.ground_height(target.x, target.z))
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	position = target + offset * distance
	position.y = maxf(position.y, Forest.ground_height(position.x, position.z) + 0.80)
	look_at(target)
