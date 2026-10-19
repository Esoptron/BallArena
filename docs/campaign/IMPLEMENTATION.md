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

| Commit | Completed stage |
|---|---|
| `189d1a2` | Isolated reviewed baseline; 40 inherited tests |
| `a395640` | Fixed-point campaign profiles and account progression |
| `23a690b` | 16 reusable weapon archetypes and bounded projectiles |
| `5c8d764` | Run transactions, rewards and cards |
| `c79ca5c` | 50 encounters and five bosses on the shared arena |
| `af9bc6c` | Versioned saves, migration, corruption recovery and resume |
| `a95cbe7` | Campaign UI, barracks, shop and experimental CI |
| `64ab2c5` | Deferred lethal wall damage and legacy-save recovery |
| `0d5ca2a` | Status lifecycle guards, post-match damage guard, scalable damage ceilings, inventory/reward edge cases |
| `e32f358` | Data-driven future modifiers, tuned encounter tempo, reproducible physics tools and real carried-HP level attempt |
| `ec0388d` | Guard shield opposite spear, stronger defensive stance, distinct lightweight boss details and ranged-weapon death portraits |

The final local verification passed **51 headless + 16 graphics = 67 Godot cases**, plus seven Python runner checks. The graphics run required ordinary shader-cache access; the initial sandbox cache error was resolved, not filtered out. New scripts were imported before verification; the latest ranged-debris assertions and boss-death render were rerun explicitly. All original character resources, textures and shaders match reviewed main. Outside `scripts/campaign/`, runtime integration is limited to the opt-in front-menu signal, launcher scene selection and optional portrait factory/preparation hooks for existing death fragments. Existing free-mode regression coverage, including 20 participants and continuous collision checks, remains.

The logical full-run test traverses all 50 saved transactions and verifies 1,640 coins, 845 XP, five boss rewards and a retained bonus for future level six. It is distinct from genuine physics simulations. A separate physical level-one attempt carries HP/cards through all ten battles; its seed and outcomes are published, without claiming one successful attempt proves universal completion.

Physics validation and numerical adjustments are documented in [BALANCE_REPORT.md](BALANCE_REPORT.md), with compressed raw cohorts, initial states and exact config/source hashes under `reports/`. Earlier cohorts retain their version identity. Only the final held-out cohorts contribute to the main tables. The optional 500-per-pair target has not been reached and is not claimed.

Final primary sample: **1,398 battles**, including 750 boss bouts (30 per hero/boss pair), 450 authored non-boss fights, 150 additional two-enemy bouts and 48 stress scenarios. The 150 guard bouts were replaced by a new held-out cohort after the final shield correction; superseded rows remain archived and are excluded explicitly. There are 5,727 archived successful physics observations across all versions, not 5,727 observations of one final balance. 17 of the primary bouts reached the 90-second observation limit; these are censored, not losses. Difficulty, long-tail katana/Archon bouts and very strong upgraded builds remain explicit balance limitations.

Main remains at `65bf05bb097b04dd1ee05749ca49eb75d87afcb7`, with a clean working directory. No APK, integration into main, destructive rollback, old-copy deletion, real payments or new topic in `PROJECT_MEMORY.md` is part of this experiment. For launch and safe rejection/integration instructions see [README.md](README.md).
