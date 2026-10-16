@tool
class_name VampireFangs
extends CombatAbility
## Visual fangs + a non-solid bite range. Damage and healing happen in unit ticks.

signal bite_started(victim: ArenaBall)
signal bite_tick(victim: ArenaBall, damage: int, healing: int)
signal bite_finished

var bite_duration: float
var bite_units: int
var heal_units: int
var recovery_time: float
var tooth_immersion: float
var capture_immunity: float
var health_speed_reference: float = 100.0
var health_speed_per_hp: float = 0.005
var health_speed_min_ratio: float = 0.25
var health_speed_max_ratio: float = 1.5
var hunt_health_threshold: int = 20
var hunt_delay: float = 3.0
var hunt_speed_bonus: float = 0.20
var hunt_used: bool = false
var hunt_pending: bool = false
var hunt_delay_remaining: float = 0.0
var hunting: bool = false
var _damage_this_bite: int = 0
var _healed_this_bite: int = 0
var _contact_rearmed: bool = true

var has_bitten: bool = false
var ticks_remaining: int = 0
var cooldown_remaining: float = 0.0
var bite_target: ArenaBall
var _tick_elapsed: float = 0.0
var _mist: Polygon2D
var _mist_outline := PackedVector2Array()
var _mist_radius: float = -1.0
var _mist_material: ShaderMaterial
var _clock: float = 0.0
var _bite_elapsed: float = 0.0
var _fixed_fang_diameter: float = 70.0
var _carry_velocity: Vector2 = Vector2.ZERO
var _drain_id: int = -1
var _pair_offset: Vector2 = Vector2.ZERO
var _victim_freeze_mode: int = RigidBody2D.FREEZE_MODE_STATIC


func _ready() -> void:
	fighter = get_parent() as ArenaBall
	configure(CharacterCatalog.ability(&"bite"))
	show_behind_parent = true
	# Teeth are behind both bodies, regardless of their order in the arena.
	z_index = -1
	_mist = Polygon2D.new()
	_mist.name = "FangMist"
	_mist.visible = false
	_mist.show_behind_parent = true
	_mist_material = ShaderMaterial.new()
	_mist_material.shader = preload("res://scripts/fang_mist.gdshader")
	_mist.material = _mist_material
	add_child(_mist)
	for index in 4:
		_mist_outline.append_array(_tooth_shape(index,1.0,0.0,6))
	_mist_material.set_shader_parameter("tooth_vertices",_mist_outline)



func _process(delta: float) -> void:
	if fighter == null:
		return
	_clock += delta
	visible = is_enabled()
	if not visible:
		return
	aim_at_opponent()
	_update_mist()
	queue_redraw()


func aim_at_opponent() -> void:
	var target := bite_target if is_instance_valid(bite_target) else fighter.opponent
	if is_instance_valid(target):
		var direction := target.global_position - fighter.global_position
		if not direction.is_zero_approx():
			rotation = direction.angle() + PI * 0.5


func is_enabled() -> bool:
	return enabled and fighter != null and fighter.is_vampire


func preferred_movement_direction() -> Vector2:
	if hunting and bite_target == null and fighter.current_health > 0 and is_instance_valid(fighter.opponent) and fighter.opponent.current_health > 0:
		return fighter.opponent.global_position - fighter.global_position
	return Vector2.ZERO

func on_damage_received(previous_health: int, damage: int) -> void:
	if not hunt_used and damage > 0 and previous_health >= hunt_health_threshold and fighter.current_health > 0 and fighter.current_health < hunt_health_threshold:
		hunt_used = true
		hunt_pending = true
		hunt_delay_remaining = hunt_delay
		emit_event(&"hunt_armed",fighter.opponent,{"delay":hunt_delay})

func _update_hunt(delta: float = 0.0) -> void:
	if fighter.current_health <= 0 or not is_instance_valid(fighter.opponent) or fighter.opponent.current_health <= 0 or (fighter.combat_director != null and fighter.combat_director.match_over):
		hunting = false
		hunt_pending = false
		return
	if hunt_pending and bite_target == null:
		hunt_delay_remaining = maxf(0.0,hunt_delay_remaining-delta)
		if hunt_delay_remaining <= 0.0 and bite_target == null:
			hunt_pending = false
			hunting = true
			_contact_rearmed = true
			fighter._last_direction = preferred_movement_direction().normalized()
			fighter.linear_velocity = fighter._last_direction*fighter.effective_movement_speed()
			fighter._sync_dynamic_speed()
			emit_event(&"hunt_started", fighter.opponent)
	if hunting:
		cooldown_remaining = 0.0
		_update_mist()

func movement_speed_multiplier() -> float:
	var health_ratio := clampf(1.0 + (health_speed_reference - fighter.current_health) * health_speed_per_hp,
		health_speed_min_ratio, health_speed_max_ratio)
	return health_ratio * (1.0+hunt_speed_bonus if hunting else 1.0)

func reset_runtime() -> void:
	hunt_used = false
	hunt_pending = false
	hunt_delay_remaining = 0.0
	hunting = false
	has_bitten = false
	cooldown_remaining = 0.0
	_contact_rearmed = true


func combat_step(delta: float) -> void:
	aim_at_opponent()
	_update_hunt(delta)
	cooldown_remaining = maxf(0.0,cooldown_remaining-delta)
	if bite_target != null:
		if not is_instance_valid(bite_target) or bite_target.current_health <= 0 or fighter.current_health <= 0:
			_finish_bite()
		else:
			_bite_elapsed += delta
			_advance_carried_motion(delta)
			var previous_elapsed := _tick_elapsed
			_tick_elapsed += delta
			var interval := bite_duration/bite_units
			var queued := 0
			while _tick_elapsed+0.000001 >= interval and queued < ticks_remaining:
				_tick_elapsed -= interval
				var fraction := clampf((interval-previous_elapsed+queued*interval)/delta,0.0,1.0)
				queue_contact(_bite_tick,fraction)
				queued += 1
		return
	if not is_instance_valid(fighter.opponent):
		return
	var contact := tooth_contact(fighter.opponent)
	if not contact:
		_contact_rearmed = true
	if contact and (_contact_rearmed or hunting) and cooldown_remaining <= 0:
		queue_contact(_contact_bite.bind(fighter.opponent),0.0)


func tooth_contact(victim: ArenaBall) -> bool:
	if not is_instance_valid(victim):
		return false
	# The two long tip coordinates come from the approved sprite, in source pixels.
	var art_rotation := global_rotation+PI
	for source_tip in [Vector2(447,903),Vector2(712,923)]:
		var offset: Vector2 = (source_tip-Vector2(626,513))*fang_diameter()/566.0
		var tip := fighter.global_position+offset.rotated(art_rotation)
		if tip.distance_to(victim.global_position) <= victim.visual_diameter()*0.5:
			return true
	return false


func _contact_bite(victim: ArenaBall) -> void:
	if tooth_contact(victim) and try_bite(victim):
		_contact_rearmed = false


func _bite_tick() -> void:
	if not is_instance_valid(bite_target) or ticks_remaining <= 0:
		return
	var victim := bite_target
	# A bite is one incoming hit; later drain units remain periodic damage.
	var damage := victim.take_damage(1,fighter,ability_id,_damage_this_bite == 0)
	_damage_this_bite += damage
	var desired_healing := floori(float(_damage_this_bite)*heal_units/bite_units)
	var healing := fighter.heal(maxi(0,desired_healing-_healed_this_bite),fighter,ability_id)
	_healed_this_bite += healing
	ticks_remaining -= 1
	bite_tick.emit(victim,damage,healing)
	if bite_target != victim:
		return
	if victim.respond_to_capture_damage(self,damage):
		return
	if ticks_remaining == 0 or victim.current_health <= 0 or fighter.current_health <= 0:
		_finish_bite()


func try_bite(victim: ArenaBall) -> bool:
	if not is_enabled() or not fighter.can_start_bite() or ticks_remaining > 0 or cooldown_remaining > 0.0:
		return false
	if not is_instance_valid(victim) or victim == fighter or victim.current_health <= 0 or victim.is_invulnerable() or victim.capture_immunity_remaining > 0:
		return false
	if director != null and not director.are_enemies(fighter,victim): return false
	if director != null and director.group_battle and victim.is_immobilized(): return false
	hunting = false
	fighter._sync_dynamic_speed()
	var opening_direction := fighter.linear_velocity.normalized()
	if opening_direction.is_zero_approx():
		opening_direction = fighter.get("_last_direction") as Vector2
	_carry_velocity = opening_direction * (fighter.adjusted_movement_speed() / 3.0)
	_victim_freeze_mode = victim.freeze_mode
	_fixed_fang_diameter = fighter.visual_diameter()
	fighter.begin_feeding(_fixed_fang_diameter)
	bite_target = victim
	ticks_remaining = bite_units
	_bite_elapsed = 0.0
	_tick_elapsed = 0.0
	cooldown_remaining = 0.0
	_damage_this_bite = 0
	_healed_this_bite = 0
	has_bitten = true
	aim_at_opponent()
	fighter.hold_motion(self)
	fighter.set_invulnerable(self, true)
	victim.hold_motion(self)
	victim.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	victim.paralyze(bite_duration,self)
	fighter.transport_velocity = _carry_velocity
	victim.transport_velocity = _carry_velocity
	_place_for_bite(victim)
	_pair_offset = victim.global_position - fighter.global_position
	if is_instance_valid(fighter.combat_effects):
		_drain_id = fighter.combat_effects.call("start_drain", fighter, victim)
	emit_event(&"cast_started",victim,{"tags":["capture","drain"],"successful":true})
	bite_started.emit(victim)
	queue_redraw()
	return true


func interrupt_bite(victim: ArenaBall) -> bool:
	if bite_target != victim:
		return false
	_finish_bite(true)
	return true

func _finish_bite(interrupted: bool = false) -> void:
	if bite_target == null:
		return
	if is_instance_valid(fighter.combat_effects) and _drain_id >= 0:
		fighter.combat_effects.call("stop_drain", _drain_id)
	_drain_id = -1
	var victim := bite_target
	fighter.transport_velocity = Vector2.ZERO
	if is_instance_valid(victim):
		victim.transport_velocity = Vector2.ZERO
	var completed := ticks_remaining == 0 and not interrupted
	var mark_spacing := fang_spacing()
	ticks_remaining = 0
	bite_target = null
	if hunt_pending:
		hunt_delay_remaining = hunt_delay
	_tick_elapsed = 0.0
	var away := Vector2.UP.rotated(global_rotation)
	if is_instance_valid(victim):
		away = (victim.global_position - fighter.global_position).normalized()
		if away.is_zero_approx():
			away = Vector2.RIGHT
		if completed and victim.current_health > 0:
			victim.apply_bite_marks(fighter.global_position, mark_spacing)
		victim.freeze_mode = _victim_freeze_mode
		victim.grant_capture_immunity(capture_immunity)
		victim.cancel_paralysis(self)
		victim.release_motion(self, away)
	cooldown_remaining = recovery_time
	_contact_rearmed = false
	emit_event(&"cast_finished",victim,{"completed":completed,"successful":true,"interrupted":interrupted})
	fighter.end_feeding()
	fighter.set_invulnerable(self, false)
	fighter.release_motion(self, -away)
	bite_finished.emit()


func _exit_tree() -> void:
	if is_instance_valid(fighter) and bite_target != null:
		_finish_bite()


func cooldown_time_left() -> float:
	return cooldown_remaining

func cooldown_full_duration() -> float:
	return recovery_time

func cooldown_visual() -> CanvasItem:
	return fighter.get_node_or_null("ApprovedVampireArt/Teeth")

func fang_diameter() -> float:
	return _fixed_fang_diameter if bite_target != null else fighter.visual_diameter()


func _advance_carried_motion(delta: float) -> void:
	_carry_velocity = _carry_velocity.normalized() * (fighter.adjusted_movement_speed() / 3.0)
	var arena := fighter.get_parent().get_parent() as BallArena
	if arena == null:
		fighter.global_position += _carry_velocity * delta
	else:
		var position_local := arena.to_local(fighter.global_position)
		var offset_local := arena.to_local(fighter.global_position + _pair_offset) - position_local
		var velocity_local := arena.to_local(fighter.global_position + _carry_velocity) - position_local
		# Sweep both circles as one rigid pair. Either body's wall contact reflects both.
		var own_radius := fighter.diameter * 0.5
		var victim_radius := bite_target.diameter * 0.5
		var lower := Vector2(maxf(own_radius, victim_radius - offset_local.x),
			maxf(own_radius, victim_radius - offset_local.y))
		var upper := Vector2(minf(arena.arena_size.x - own_radius,
			arena.arena_size.x - victim_radius - offset_local.x),
			minf(arena.arena_size.y - own_radius,
			arena.arena_size.y - victim_radius - offset_local.y))
		position_local = position_local.clamp(lower, upper)
		var remaining := delta
		for impact in 8:
			var hit_x := INF
			var hit_y := INF
			if absf(velocity_local.x) > 0.000001:
				var boundary := upper.x if velocity_local.x > 0.0 else lower.x
				hit_x = maxf(0.0, (boundary - position_local.x) / velocity_local.x)
			if absf(velocity_local.y) > 0.000001:
				var boundary := upper.y if velocity_local.y > 0.0 else lower.y
				hit_y = maxf(0.0, (boundary - position_local.y) / velocity_local.y)
			var contact_time := minf(hit_x, hit_y)
			var travel := minf(remaining, contact_time)
			position_local += velocity_local * travel
			remaining -= travel
			if contact_time > travel:
				break
			if hit_x <= hit_y + 0.0000001:
				velocity_local.x = -velocity_local.x
			if hit_y <= hit_x + 0.0000001:
				velocity_local.y = -velocity_local.y
			if remaining <= 0.0000001:
				break
		fighter.global_position = arena.to_global(position_local)
		_carry_velocity = arena.to_global(velocity_local) - arena.to_global(Vector2.ZERO)
	bite_target.global_position = fighter.global_position + _pair_offset
	fighter.transport_velocity = _carry_velocity
	bite_target.transport_velocity = _carry_velocity


func fang_spacing() -> float:
	# The separation of the two long tooth tips, including their inward tilt.
	return fang_diameter() * (274.0 / 566.0)


func fang_tip_depth() -> float:
	return fang_diameter() * 0.5 * 1.45


func _place_for_bite(victim: ArenaBall) -> void:
	var toward := (victim.global_position - fighter.global_position).normalized()
	if toward.is_zero_approx():
		toward = Vector2.UP.rotated(global_rotation)
	var radius := fang_diameter() * 0.5
	var victim_radius := victim.visual_diameter() * 0.5
	var half_spacing := fang_spacing() * 0.5
	var exposed_length := fang_tip_depth() - sqrt(radius * radius - half_spacing * half_spacing)
	var victim_surface := sqrt(maxf(0.0, victim_radius * victim_radius - half_spacing * half_spacing))
	var separation := fang_tip_depth() + victim_surface - exposed_length * tooth_immersion
	# Keep the circular bodies separate even if a low-health pulse later grows.
	separation = maxf(separation, (fighter.diameter + victim.diameter) * 0.5 + 0.5)
	fighter.global_position = victim.global_position - toward * separation
	# At a wall, translate the pair together instead of pushing a body through it.
	var arena := fighter.get_parent().get_parent() as BallArena
	if arena != null:
		var fighter_radius := fighter.diameter * 0.5
		var target_radius := victim.diameter * 0.5
		var footprint := Rect2(arena.to_local(fighter.global_position) - Vector2.ONE * fighter_radius,
			Vector2.ONE * fighter.diameter).merge(Rect2(
			arena.to_local(victim.global_position) - Vector2.ONE * target_radius,
			Vector2.ONE * victim.diameter))
		var shift := Vector2(
			clampf(0.0, 0.5 - footprint.position.x, arena.arena_size.x - 0.5 - footprint.end.x),
			clampf(0.0, 0.5 - footprint.position.y, arena.arena_size.y - 0.5 - footprint.end.y))
		var world_shift := arena.to_global(shift) - arena.to_global(Vector2.ZERO)
		fighter.global_position += world_shift
		victim.global_position += world_shift
	rotation = toward.angle() + PI * 0.5
	fighter.reset_physics_interpolation()
	victim.reset_physics_interpolation()


func _update_mist() -> void:
	if not is_instance_valid(_mist):
		return
	_mist.visible = is_enabled() and bite_target == null and cooldown_remaining > 0.0
	if not _mist.visible:
		return
	var radius := fighter.visual_diameter()*0.5
	if not is_equal_approx(radius,_mist_radius):
		_mist_radius = radius
		_mist.polygon = PackedVector2Array([
			Vector2(-1.45,-2.35)*radius,Vector2(1.45,-2.35)*radius,
			Vector2(1.45,-0.35)*radius,Vector2(-1.45,-0.35)*radius])
		_mist_material.set_shader_parameter("fang_radius",radius)
	_mist_material.set_shader_parameter("mist_clock", _clock)


# Contours sampled from the approved source, used only for the animated mist.
# The character itself is rendered from its original pixels.
func _tooth_shape(index: int, _radius: float, _inset: float = 0.0, _steps: int = 6) -> PackedVector2Array:
	var outlines := [
		[Vector2(389, 696), Vector2(382, 735), Vector2(384, 775), Vector2(392, 812), Vector2(408, 851), Vector2(428, 883), Vector2(447, 903), Vector2(442, 875), Vector2(449, 829), Vector2(458, 781), Vector2(467, 735), Vector2(454, 715), Vector2(422, 701), Vector2(402, 693)],
		[Vector2(522, 750), Vector2(525, 782), Vector2(532, 812), Vector2(543, 838), Vector2(552, 850), Vector2(557, 833), Vector2(559, 804), Vector2(559, 779), Vector2(558, 760), Vector2(550, 750), Vector2(543, 749), Vector2(536, 749), Vector2(529, 750), Vector2(524, 751)],
		[Vector2(641, 756), Vector2(637, 780), Vector2(637, 807), Vector2(635, 831), Vector2(628, 857), Vector2(640, 845), Vector2(651, 825), Vector2(660, 799), Vector2(664, 774), Vector2(659, 760), Vector2(653, 755), Vector2(647, 755), Vector2(642, 756), Vector2(640, 757)],
		[Vector2(749, 751), Vector2(746, 786), Vector2(738, 826), Vector2(730, 865), Vector2(712, 923), Vector2(738, 898), Vector2(766, 866), Vector2(789, 829), Vector2(804, 789), Vector2(811, 751), Vector2(809, 726), Vector2(800, 716), Vector2(777, 732), Vector2(760, 746)],
	]
	var result := PackedVector2Array()
	for point: Vector2 in outlines[index]:
		result.append(-(point - Vector2(626, 513)) / 283.0)
	return result


func _draw() -> void:
	if not is_enabled() or not hunting or fighter.current_health <= 0:
		return
	var heading := fighter.linear_velocity.normalized()
	if heading.is_zero_approx(): heading = preferred_movement_direction().normalized()
	if heading.is_zero_approx(): return
	var forward := heading.rotated(-global_rotation)
	var side := forward.orthogonal()
	var radius := fighter.visual_diameter()*0.5
	for index in 7:
		var phase := fmod(_clock*2.3+index*0.173,1.0)
		var lane := (index-3)*radius*0.26
		var tail := radius*(0.8+phase*2.1)
		var length := radius*(0.55+0.25*sin(index*1.7))
		var points := PackedVector2Array()
		for sample in 9:
			var t := sample/8.0
			points.append(-forward*(tail+length*t)+side*(lane+sin(t*PI)*radius*0.12))
		var alpha := sin(phase*PI)*0.48
		draw_polyline(points,Color(0.72,0.90,1.0,alpha),1.3,true)
