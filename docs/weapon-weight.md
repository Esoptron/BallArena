# Body and weapon weight

Canonical profiles: characters/*.tres (weight_class and diameter_multiplier), abilities/*.tres (weapon_weight_class and impact_strength).

| Index | Category | Relative mass |
|---|---|---|
| 0 | Light | 0.6 |
| 1 | Below average | 0.8 |
| 2 | Medium | 1.0 |
| 3 | Above average | 1.3 |
| 4 | Heavy | 1.6 |

Shared factors live in scripts/combat/weight_classes.gd. Body mass feeds Godot's collision solver. Size is independent of mass: swordsman diameter multiplier 1.0, vampire 1.1 (70 and 77 at arena diameter 70).

Successful sword hits add a directional velocity impulse of impact_strength * weapon_mass / target_mass, then normalize to the target's current base speed plus its temporary wall-speed bonus. Direction follows the blade sweep with an outward component. Thus heavier weapons deflect more and heavier characters resist more. Directional weapon impacts do not create temporary speed boosts; weight-dependent wall acceleration is described in motion-dynamics.md.

Abilities use CombatAbility.apply_weapon_impact; damage and weight are independent. Blocked hits, dead bodies and held/captured bodies receive no impulse. Bite is a grip/drain with medium fang weapon category and impact_strength 0: damage ticks do not repeatedly knock back the captured pair.

Sword remains on a 1-second game-time cooldown, 3 seconds at one-third angular speed after a successful hit, reversing direction after each hit. Automatic simulations use the same masses, sizes and impact rules and record weapon_impact events plus profile metadata. Previous balance results predate these changes.
