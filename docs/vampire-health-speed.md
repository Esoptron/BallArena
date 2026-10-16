# Vampire speed and HP

The bite profile contains the configurable linear rule:
`ratio = clamp(1 + (100 - HP) * 0.005, 0.25, 1.5)`.

At 100 HP the vampire uses its normal movement speed; at 150 HP it uses 75%; at 50 HP 125%; at 1 HP 149.5%. At very high HP a floor of 25% keeps the vampire moving. Death still stops motion completely.

The rule is a runtime ability multiplier. It does not rewrite or compound the configured base speed. Wall bonuses use the adjusted base, and normal collision reflections and weapon impacts retain their existing directions. The attached pair still moves at one third of the vampire's speed during the three-second bite, updating its pace as the vampire heals. The unchanged bite damage/healing and recovery parameters still come from the bite resource. Simulations use the same ability.

The arena's upper-right corner displays two unlabelled numbers, blue and red. They show actual game movement speed including wall bonuses and pair transport, or zero for stopped/dead actors. They show no units, captions, or critical stack count.
