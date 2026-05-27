class_name AbilityVisualSpawner
extends RefCounted

## Centralises particle and visual effects so individual abilities don't
## duplicate particle setup code.
##
## Extracted and generalized from SporeBurst._spawn_burst_visual().
## All methods are static — no instance state needed.
## All spawned nodes are attached to the actor/scene and auto-clean up.
##
## No external dependencies. Purely additive visuals.

## Spherical particle burst at the actor's feet.
## Used by: SporeBurst, on-impact effects, death bursts, hit confirmations.
static func burst(actor: Actor, radius: float, color: Color,
		lifetime: float = 0.7) -> void:
	if not is_instance_valid(actor):
		return

	var particles := GPUParticles3D.new()
	actor.add_child(particles)
	particles.transform.origin = Vector3.ZERO
	particles.amount  = 24
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape             = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius     = radius * 0.4
	mat.direction                  = Vector3(0, 1, 0)
	mat.initial_velocity_min       = 0.5
	mat.initial_velocity_max       = 1.4
	mat.scale_min                  = 0.05
	mat.scale_max                  = 0.12
	mat.color                      = color
	particles.process_material = mat

	_auto_free_after(actor, particles, lifetime + 0.5)

## Cone-shaped spray from the actor in a direction.
## Used by: breath weapons, cone-shaped abilities.
## length_tiles determines how far the effect travels (1 tile ≈ 1.5 world units).
static func cone(actor: Actor, direction: Vector3, length_tiles: int,
		color: Color) -> void:
	if not is_instance_valid(actor):
		return

	var length_world: float = float(length_tiles) * 1.5

	var particles := GPUParticles3D.new()
	actor.add_child(particles)
	particles.transform.origin = Vector3.ZERO
	particles.amount  = 40
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape         = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.2
	mat.direction              = direction.normalized()
	mat.spread                 = 30.0  # degrees of cone spread
	mat.initial_velocity_min   = length_world * 0.8
	mat.initial_velocity_max   = length_world * 1.2
	mat.scale_min              = 0.08
	mat.scale_max              = 0.18
	mat.color                  = color
	particles.process_material = mat

	_auto_free_after(actor, particles, 0.9)

## Traveling projectile that moves from one actor to another.
## on_arrive fires when the projectile reaches the target.
## Used by: Death Ray, Psychic Orb, Lightning Bolt, Rotting Gaze, etc.
static func projectile(from: Actor, to: Actor, color: Color,
		on_arrive: Callable) -> void:
	if not is_instance_valid(from) or not is_instance_valid(to):
		if on_arrive.is_valid():
			on_arrive.call()
		return

	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius      = 0.12
	sphere.height      = 0.24
	orb.mesh           = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color      = color
	mat.emission_enabled  = true
	mat.emission          = color * 1.5
	mat.shading_mode      = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb.material_override = mat

	from.get_tree().root.add_child(orb)
	orb.global_position = from.global_position + Vector3(0, 0.8, 0)

	var target_pos: Vector3 = to.global_position + Vector3(0, 0.8, 0)
	var travel_time: float  = 0.25

	var tween: Tween = orb.create_tween()
	tween.tween_property(orb, "global_position", target_pos, travel_time)
	tween.tween_callback(func():
		if on_arrive.is_valid():
			on_arrive.call()
		if is_instance_valid(orb):
			orb.queue_free()
	)

## Persistent ring / halo for ongoing aura effects.
## Returns the Node3D so the caller can queue_free() it when the aura ends.
## Used by: Fear Aura, Stench, Blazing Presence, Radiance, etc.
## pulse = true causes a gentle scale breathing animation.
static func ring(actor: Actor, radius_tiles: int, color: Color,
		pulse: bool = false) -> Node3D:
	if not is_instance_valid(actor):
		return null

	var ring_node := Node3D.new()
	actor.add_child(ring_node)
	ring_node.position = Vector3.ZERO

	var particles := GPUParticles3D.new()
	ring_node.add_child(particles)
	particles.amount   = 60
	particles.lifetime = 1.8
	particles.one_shot = false
	particles.emitting = true

	var world_radius: float = float(radius_tiles) * 1.5

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape        = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius  = world_radius
	mat.emission_ring_height  = 0.05
	mat.emission_ring_inner_radius = world_radius * 0.9
	mat.direction             = Vector3(0, 1, 0)
	mat.initial_velocity_min  = 0.05
	mat.initial_velocity_max  = 0.15
	mat.scale_min             = 0.06
	mat.scale_max             = 0.10
	mat.color                 = color
	particles.process_material = mat

	if pulse:
		var tween: Tween = ring_node.create_tween().set_loops()
		tween.tween_property(ring_node, "scale", Vector3(1.04, 1.0, 1.04), 1.0)
		tween.tween_property(ring_node, "scale", Vector3(0.96, 1.0, 0.96), 1.0)

	return ring_node

## Floating popup text above an actor (damage numbers, condition names, misses).
## Text fades out after ~0.9 seconds.
static func popup_text(actor: Actor, text: String, color: Color) -> void:
	if not is_instance_valid(actor):
		return

	var label := Label3D.new()
	label.text             = text
	label.modulate         = color
	label.font_size        = 28
	label.billboard        = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test    = true
	label.fixed_size       = true
	actor.add_child(label)
	label.position = Vector3(0, 2.0, 0)

	var tween: Tween = label.create_tween()
	tween.tween_property(label, "position", Vector3(0, 2.8, 0), 0.7)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tween.tween_callback(label.queue_free)

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Auto-free a node after delay_seconds using a one-shot Timer on the actor.
static func _auto_free_after(actor: Actor, node: Node, delay_seconds: float) -> void:
	if not is_instance_valid(actor):
		return
	var timer := Timer.new()
	timer.one_shot   = true
	timer.wait_time  = delay_seconds
	actor.add_child(timer)
	timer.timeout.connect(func():
		if is_instance_valid(node):   node.queue_free()
		if is_instance_valid(timer):  timer.queue_free()
	)
	timer.start()
