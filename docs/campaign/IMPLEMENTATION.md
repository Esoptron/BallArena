# Campaign experiment — implementation state

## Scope and immutable boundaries

- Active worktree: `C:\Users\STerrible\Documents\Codex\campaign-experiment`, branch `campaign-experiment`.
- Main checkout and `main` must not be edited. Original rollback checkpoint: `cdb9b703da7dcf53c74433e479e69cf4097edc7e`, tag `campaign-experiment-baseline-20261017`.
- Reviewed main source at start: `65bf05bb097b04dd1ee05749ca49eb75d87afcb7`. Its engineering fixes are copied into the clean experiment as a separate preparation commit, without merge/rebase/reset or moving the original checkpoint.
- User explicitly authorizes publishing this task's commits to the experimental branch. Never push main or checkpoint tags.
- Free battle remains a parallel mode with the original six profiles, balance, collision framework, visuals and roster selection. Campaign enemies stay in a separate catalog and never appear in the free battle picker.
- Latest user clarification overrides the attachment: vampire bite distance/teeth geometry **stay unchanged**. Weapon rarity does not shorten or lengthen vampire fangs.
- Confirmed by the user: five levels × ten battles = fifty, with a boss in battle ten of each level.
- No APK. No real payments, ads, playable allies, evolutions or procedural replacement of the fifty authored encounters.
- Original user specification is preserved in `SPECIFICATION.md`; latest direct user clarification takes precedence.
- Existing `PROJECT_MEMORY.md` maintenance rule remains: update existing facts; do not add new campaign topics there without an explicit request.

## Architecture audit / intended isolation

Existing code uses integer HP/damage; abilities and combat signals are typed int. Do not convert the entire free battle system to floats. Campaign actors use fixed point (1000 internal units per displayed HP) with campaign-only formatting, bleed and bite adapters. Fractional damage/growth is exact to a thousandth; existing Director/metrics/status/weight/sweep code is reused.

- `scripts/campaign/data/`: player progression, enemy/weapon archetypes, modifiers, boss configurations, authored levels and reward weights. Separate from `characters/` to preserve free battles.
- `scripts/campaign/`: deterministic profile calculation, run state, atomic versioned saves, catalog, arena adapter and launcher/UI.
- `scripts/campaign/combat/`: campaign actor and ability adapters, reusable melee geometry, finite swept projectiles, bounded periodic/status effects, boss behaviours. No per-encounter script.
- Campaign arena reuses the existing walls, body solver, director, weight response, effects and death fragments. Team checks apply to all damage/control/projectiles.
- Minimal opt-in menu signal + campaign launcher selects the new screen. Normal launcher, arena scene and free picker retain their API/default behaviour.
- Account state (coins/shared XP, owned heroes, individual ranks, trained ability ranks, weapon inventory/equipment, level unlocks, boss wins, ally-slot placeholder and next-level bonus) is separate from active run state and per-battle growth.
- Run state carries HP, vampire peak HP and additive selected cards. Each encounter constructs a fresh actor/profile, so hit growth/status effects never accumulate across battles accidentally.
- Saves use a campaign-specific versioned path, validate before mutation, preserve corrupt data as backup, use an atomic temporary write and guard reward/card resolution by encounter identity.

## Stages and acceptance

- Preparation: bring reviewed source to experiment; preserve rollback baseline; import and run inherited regression suite; commit.
- A: configs, progression formulas, fixed-point actor/bite adapters, invariance/round-reset tests; commit.
- B: sixteen distinct enemy weapons/archetypes, projectile/status/shield/geometry tests; commit.
- C: isolated campaign UI, sequential encounter/run/cards state machine, scene-transition/idempotency tests; commit.
- D: fifty authored battles, five bosses, capped drone summon, boss/roster tests; commit.
- E: barracks/shop/shared XP/individual ranks/ability training/weapon merge, economy tests; commit.
- F: versioned saves/resume/migration/corruption handling, future ally/evolution/damage metadata placeholders; commit.
- G: broad regression/render checks, genuine seeded simulations and balance report; commit and push experimental branch.

## Verification requirements

- Run inherited free battle tests before/after, compare original `.tres` and assets, and fixed-seed battle traces. Campaign changes must not rebalance free battles.
- Test every enemy weapon's damage geometry and rate limits, friendly fire exclusion, projectiles at walls, bounded periodic effects/control, dynamic vampire max HP, round resets, card rarity/eligibility, next-level boss reward, persistence and reward deduplication.
- Simulations must instantiate actual campaign scenes/abilities with isolated World2D, not an approximate replacement combat model. Record metrics, seeds, upgrade tier and exact config hashes. Report actual sample counts, duration/wins/HP/hits/ability activations/periodic damage, including two-enemy battles.
- Target at least 500 runs per playable hero/boss pair across several realistic upgrade states if feasible; never claim unexecuted runs.
- All scripts, captures and logs stay under this worktree. Use `builds/campaign-work/` for temporary generators, diagnostics and reports, preserving `builds/campaign-experiment-safety/`.

## Current status

Preparation is committed as `189d1a2`; inherited tests passed 40/40. Stage A implements campaign-only fixed-point health, five player profiles, shared XP/individual ranks, ability training and weapon merging formulas. Campaign vampire retains the original geometry and three-second capture; fractional bite budgets and growth apply once per completed bite. Stage A tests passed 41/41, including the new progression/invariance test. The main checkout is untouched.

Stage A: `a395640`. Stage B: `23a690b` (16 archetypes, swept projectiles, sector shield, distinct damage shapes), 42/42 tests. Both are published only on `campaign-experiment`.

The next integrated stages implement the explicit run transaction, card eligibility/additive bonuses, 50 authored encounters, five bosses, bounded one-time drone summon, campaign arena/layout, barracks/shop and versioned saves. The full headless suite passed 47/47 after updating the two old menu tests for the deliberately changed campaign entry; their free-roster/physics coverage remains. Save tests cover checksums, migration, interrupted battles, reward deduplication, corrupt-file backup recovery and refusing newer save versions. State/content/save/UI changes are split into separate logical commits.

The first physics pilot is still running; no balance conclusions or unexecuted sample counts are claimed. It instantiates actual actors in isolated World2D spaces with seeded positions/directions and ±12% initial speeds. New scenarios will be reserved for final validation.
