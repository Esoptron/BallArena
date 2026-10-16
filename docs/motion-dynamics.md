# Weight-dependent wall speed

The base movement_speed (including permanent sword progression) is separate from wall_speed_bonus. effective_movement_speed() returns their sum. Wall contacts refill a bounded temporary bonus, never stack it. Corner contacts therefore do not multiply speed. The bonus decays linearly in game time over boost_decay_seconds (default 3 seconds).

| Body category | Normal wall bonus |
|---|---|
| Light | +60% |
| Below average | +45% |
| Medium | +30% |
| Above average | +20% |
| Heavy | +12% |

Weight defaults live in scripts/combat/weight_classes.gd. Character resources expose wall_boost_scale (default 1) and boost_decay_seconds. These are applied by the shared catalog in both playable fights and automated simulations, and recorded in BalanceSnapshot.

Actual RigidBody2D contacts supply collision normals. The normalized closing velocity along that normal measures contact strength: full head-on = 1, grazing = smaller. The fraction of temporary bonus lost is clamp(strength * 2 * other_mass / (own_mass + other_mass), 0, 1). Equal-weight head-on contact removes both bonuses and restores each character's own current base speed. A heavier body loses a smaller fraction against a light one. Glancing collisions preserve more speed. Native physics determines the outgoing directions; only the speed bonus is changed.

Each new contact is handled once until separation, and each body pair is resolved once per physics frame. Updating the second body's actual speed is deferred until after the solver callbacks, preserving native reflections. Fragment contacts do not cause wall boosts or character collision damping. Weapon hits retain the current bonus. During a vampire bite, the existing one-third-base-speed pair movement remains; free-flight wall bonuses decay while the pair is held.

For extreme tiny/fast editor values, additional wall bonus is limited so the boosted speed adds no further risk beyond half a body diameter per physics step. This does not change the configured base speed and does not affect the current 70/77-unit characters at 320/400 speed.

Tests: wall_speed_test.gd covers actual wall collisions across all five categories, decay, actual head-on/glancing/mixed-weight body contacts, opposite bounce directions, no stacking, and weapon impact preservation. prototype_test.gd covers walls/corners/body reflection, dynamic speed normalization, tiny fast balls and fixed-arena screen layouts. Vampire/sword/weight/clash tests retain their ability guarantees.
