# Knife capture counter

Each successful unit of vampire bite damage gives a living knife fighter an independent seeded 3.5% counter roll. This is per damage tick, not per capture. Fifteen opportunities give `1 - 0.965^15 = 41.40%` probability of at least one activation, assuming the victim survives long enough. Blocked/zero damage, ordinary weapon damage, other character classes and fatal damage do not roll this passive.

A successful counter interrupts the bite immediately, clears its protection and holds, ends drain effects, and preserves normal vampire recovery and victim capture immunity. Remaining queued bite callbacks do nothing. The final fifteenth tick can also counter rather than finish normally. The knife fighter blinks behind the vampire's pre-counter facing, leaving both bodies moving away from each other. At boundaries the pair receives only the minimal placement correction needed to fit both bodies behind one another inside the arena.

Damage is 20% of the vampire's current HP, sampled after damage/healing for that bite tick, rounded up to whole HP. This is not 20% of the reference HP and is not added to the regular dagger damage. The counter uses the usual real damage/health-number path after bite invulnerability is removed. A successful damaging counter grants normal knife damage/spin progression and starts its normal weapon cooldown, without consuming or being prevented by a pre-existing ordinary dagger cooldown.

A long tapered red cut crosses the vampire, briefly flashes with a pale hot center, expands slightly and disappears in 0.32 game seconds. Three shared glossy blood drops are emitted. No frame pause, global slowmo or persistent extra particle service was introduced.

Settings live in characters/abilities/daggers.tres: capture_counter_chance, capture_counter_hp_fraction, capture_counter_gap. Future capture responses can use the shared CombatAbility.on_capture_damage interface. Ordinary sword, katana and vampire captures keep their existing mechanics.

Counter relocation happens while both bodies are still held, before waking the rigid bodies. Placement leaves a speed-dependent two-physics-step wall margin, and release explicitly applies the new departure velocities.
