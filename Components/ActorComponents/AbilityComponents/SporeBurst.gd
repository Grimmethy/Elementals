class_name SporeBurst
extends AbilityAction

## Spore Burst — Mushroom Monster v1 area ability.
##
## Releases a cloud of toxic spores in a small radius around the caster. Every
## non-ally Actor within radius takes `POISON_DAMAGE` poison damage and is
## stunned for STUN_DURATION. A short-lived particle effect spawns at the
## caster's feet so the player can see the burst.
##
## TileSystem integration: v1 does NOT add a new TileConstants.Type. A later
## patch can wire a "spore" tile state (lingering poison field) by:
##   1) adding TileConstants.Type.SPORE
##   2) adding HexTileData.spore_duration
##   3) adding TileSystem._process_spore() and _get_next_check_time case
## The radius parameter and burst-radius mutation field are already plumbed
## through the mushroom genome to make that follow-up trivial.

const BURST_RADIUS_BASE: float = 2.2
const POISON_DAMAGE: float = 4.0
const STUN_DURATION: float = 0.6
const COOLDOWN: float = 7.5

var _cooldown_left: float = 0.0

func _init(p_actor: Actor, p_component: Node) -> void:
	super(p_actor, p_component)
	ability_name = "Spore Burst"
	ability_description = "Release a toxic cloud of spores that poisons nearby foes."
	ability_usage = "Press R to release spores around you."

func can_execute(type: String) -> bool:
	return type == "ability_r" and _cooldown_left <= 0.0 and actor != null and not actor.is_dead

func execute(type: String, _value = null) -> void:
	if not can_execute(type):
		return
	var radius: float = _resolve_burst_radius()
	var struck_count: int = _apply_burst_damage(radius)
	_spawn_burst_visual(radius)
	_cooldown_left = COOLDOWN
	_emit_message("%s released a spore burst, hitting %d target(s)." % [actor.name, struck_count])

func update(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)

func _resolve_burst_radius() -> float:
	var bonus: float = 0.0
	# Read MushroomData genome for the radius bonus if available.
	if actor and "mushroom_data" in actor and actor.mushroom_data:
		var g: Variant = actor.mushroom_data.genome
		if g is Dictionary:
			var mutation: Dictionary = g.get("mutation", {})
			bonus = float(mutation.get("spore_burst_radius_bonus", 0.0))
	return BURST_RADIUS_BASE + bonus

func _apply_burst_damage(radius: float) -> int:
	var arena_value: Variant = actor.get("_arena_grid")
	if not (arena_value is ArenaGrid):
		return 0
	var arena: ArenaGrid = arena_value as ArenaGrid
	var struck: int = 0
	for node in arena.actors:
		if not is_instance_valid(node) or not (node is Actor):
			continue
		var candidate: Actor = node as Actor
		if candidate == actor or candidate.is_dead:
			continue
		if actor.has_method("is_ally") and actor.is_ally(candidate):
			continue
		var flat: float = Vector2(
			candidate.global_position.x - actor.global_position.x,
			candidate.global_position.z - actor.global_position.z
		).length()
		if flat > radius:
			continue
		var dir: Vector3 = (candidate.global_position - actor.global_position).normalized()
		candidate.take_damage(POISON_DAMAGE, "poison", dir)
		if candidate.has_method("stun"):
			candidate.stun(STUN_DURATION)
		struck += 1
	return struck

func _spawn_burst_visual(radius: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var particles := GPUParticles3D.new()
	actor.add_child(particles)
	particles.transform.origin = Vector3.ZERO
	particles.amount = 24
	particles.lifetime = 0.7
	particles.one_shot = true
	particles.emitting = true
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = radius * 0.4
	mat.direction = Vector3(0, 1, 0)
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.4
	mat.scale_min = 0.05
	mat.scale_max = 0.12
	mat.color = Color(0.55, 0.85, 0.45, 0.85)
	particles.process_material = mat
	# Auto-cleanup after the burst lifetime.
	var cleanup_timer := Timer.new()
	cleanup_timer.one_shot = true
	cleanup_timer.wait_time = 1.2
	actor.add_child(cleanup_timer)
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(particles): particles.queue_free()
		if is_instance_valid(cleanup_timer): cleanup_timer.queue_free()
	)
	cleanup_timer.start()

func _emit_message(text: String) -> void:
	print("[Mushroom] ", text)
	if actor and actor.get_node_or_null("/root/QuestEvents"):
		QuestEvents.message(text)
