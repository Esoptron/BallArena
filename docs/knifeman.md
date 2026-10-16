# Knifeman

Catalog ID: knifeman. Available on either side in the character menu and as the fourth legacy character choice on Arena. Profiles: characters/knifeman.tres and characters/abilities/daggers.tres.

- Body: 90 starting/reference HP, light relative mass 0.6, diameter multiplier 0.7 (49 at arena diameter 70). Same ordinary body styling and team colors. Wall speed dynamics use the existing light category.
- Weapon: two light daggers exactly PI radians apart, sharing an orbit and 1-second damage cooldown. Damage starts at 6, increases by 1 on successful damage, capped at 14. Orbit starts at 8 radians/sec, gains 4 on each successful hit, capped at 32. No permanent body-speed growth and no post-hit orbit slowdown. These are initial tuning values, not a claim of equal win rates.
- Both blades detect swept body contact and participate in the generic weapon-clash interface. Body and weapon contacts reverse the pair's orbit. Damage-blocked hits cannot progress damage/spin or emit blood. The shared contact latch prevents a continuous overlap from causing repeated reversals.
- Each successful hit emits the existing tapered slash and exactly three large blood drops; impact splashes and persistent merged surface pools are shared. HP/damage numbers also use existing services. Current global sword slow motion remains specific to the sword.
- Death snapshots include both daggers; surviving daggers use the generic temporary shard colliders. Portraits in the menu use the real ability drawing. The body and melee behavior are reused rather than a new graphical style or a second physics implementation.

Implementation: scripts/knifeman.gd extends the shared orbit/contact implementation in SwordAbility and overrides dual segments and weapon drawing. Spin growth has a successful-hit hook. Generic simulations discover the new profile and ability without character-specific runner changes.

Checks: knifeman_test.gd (body/HP/weight, both sides, shared cooldown, growth/caps/reset, protected hits, slash/blood, body reflection, actual dagger/sword clash); character_selection_test.gd (both UI roles and responsive four-character grid); render_knifeman_test.gd; death_fragments_test.gd with knifeman argument; combat_balance.gd using knifeman_smoke.json.
