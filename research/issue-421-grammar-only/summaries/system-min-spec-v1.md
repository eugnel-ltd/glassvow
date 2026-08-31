# STREAM B — minimum Dusk-scoped Ward cash-out system, v1

**Specification for Codex. Not an implementation, not an authorisation, not a preregistration.**
Nothing in this file may be built until Ash authorises it. No rows, no candidate, no branch.

Companion: `design-verdict-v1.md` (STREAM A = FAIL CLOSED). Frozen source identities are listed
there and are not repeated; this spec is written against
`c28ae38824f7ba2168b573002ab8b90dadd5bde1`.

## 0. Objective in one sentence

Give Duskblade a **second destination whose terminal is spending Ward for damage**, at the smallest
engine surface that can exist, without unbundling Stun from `_shatter_enemy` and without any effect
reaching the Ashwarden.

## 1. Why any engine change is required (causal necessity)

From `design-verdict-v1.md`, measured on the frozen source:

- **F2** — `cb.player.block` is read at exactly five sites in the engine
  (`combat.gd:353`, `:460-461`, `:645-646`, `:972`, `:1359`) and none of them converts Ward into
  progress. `doubleBlock` is Ward → Ward. A Ward destination has **no terminal**. No arrangement of
  cards can create one, because effect kinds are a closed match statement (`combat.gd:861-947`).
- **F1** — the only Dusk-exclusive mechanism, chip, is bundled to `type == "attack"`
  (`combat.gd:814`), so a Ward route built out of attacks is shatter-fat by construction.
- **F5/F6** — the arm-1 cohort that defines reachability has no policy handle for Ward spending; the
  one prior grammar-only Ward package measured 1/200 and 0/200 activation.

Exactly one of these is a **grammar** gap (F2). It is closed by one new effect kind. The others
constrain how that kind must behave, and F5/F6 force a policy term. Everything else stays shut.

## 2. Surfaces — exactly four, each with the finding it closes

| # | Surface | Closes | Kind of change |
|---|---|---|---|
| S1 | Data-driven play gate on card data | makes the cash-out a decision, not a dead play | one generic read in `can_play` + preview mirror |
| S2 | One new effect kind: spend Ward → damage | **F2**, the missing terminal | one arm in `_apply_effect` + one preview arm |
| S3 | Optional `aspect` field honoured by the reward pool | Dusk scope, Ash inertness by construction | one filter in `RewardRules.card_pool` |
| S4 | One pilot valuation term for S2 | **F5/F6**, otherwise the destination reads ≈0% | research tooling only, new pilot identity |

**Not added, and must not be added:** no new `special` id; no new status; no new resource; no new
persistent state; no change to `_shatter_enemy`, to Stun, to `apply_chips`, to the chip/attack
bundling, or to any existing card's values.

### S1 — data-driven play gate

Card data may carry an optional object:

```json
"requires": { "wardAtLeast": 10 }
```

Contract:

- `can_play` (`combat.gd:746`) reads `d.get("requires", {})` in **one generic loop over supported
  keys**, not a per-card or per-id branch. Exactly one key is supported in v1: `wardAtLeast` (int) —
  legal only when `cb.player.block >= n`.
- An unknown key inside `requires` **fails closed**: the card is unplayable and `ContentDB`
  validation reports a fault. Never silently ignore.
- `preview_play` must expose the same predicate so the pilot and the UI agree; a card that fails its
  gate previews `null`.
- The field is absent on all 61 existing cards, so `can_play` behaviour for shipped content is
  bit-identical.

### S2 — the cash-out effect kind

```json
{ "kind": "wardBurst", "spend": 10, "per": 2 }
```

Contract, in this exact order, deterministic, no RNG:

1. If `run.aspect != 0`, return immediately with **no state write and no queued event** — the exact
   precedent and shape of `apply_chips` (`combat.gd:667-668`).
2. `spend := min(fx.spend, cb.player.block)`. With S1's gate in place `spend == fx.spend`; the `min`
   is the fail-closed guard, not a design feature.
3. `cb.player.block -= spend`; queue one `wardSpend` event `{t, n: spend, total: block_after}`.
4. `damage := spend * fx.per` — integer arithmetic only.
5. Apply through the existing `hit_enemy(run, cb, target, damage, false)`.

`is_attack = false` is load-bearing and must not be "improved":

- it keeps `str`/`weak`/`vulnerable` out of the law (`combat.gd:550-555`), so the cash-out is
  **deterministic** and cannot compound with the shatter route's `vulnerable 2`;
- it does not set the per-card chip flag (`combat.gd:579-582`), so the cash-out can never feed a
  shatter — the separation this whole destination exists to create;
- it skips enemy `thorns` retaliation, matching how Lantern Art damage already behaves
  (`combat.gd:1216-1223`).

`allEnemies` targeting is **out of scope for v1**: single target only. Ward is spent once; splitting
it across enemies is a second design question and a second power axis.

### S3 — Dusk scope, two independent guards

Card pools are aspect-blind today: `RewardRules.card_pool` (`rewards.gd:40-56`) is a tier list plus
`run.unlocks`, and the balance profile grants only `["aspect2"]` (`balance_sim.gd:78`), so a new card
must live in a base `cardPools` tier where Ashwarden would also be offered it.

- **Availability guard (S3):** an optional card field `"aspect": "duskblade"`, honoured by
  `card_pool` as a filter against `content.aspects[run.aspect].id`. Absent field = both aspects, so
  every existing card is unaffected. This makes the card unreachable for Ash through card rewards,
  shops and events, which all route through `card_pool`.
- **Behaviour guard (S2.1):** the aspect early-return, which makes the effect inert even if a future
  path ever puts the card in an Ash deck.

Both are specified. Highest caution means the invariant is enforced twice and asserted once:
**zero `wardSpend` events in any Ashwarden row**, in the same form as H10.

### S4 — the policy term (research tooling, and the part most likely to be skipped)

EP4 is the evidence: a grammar-only Ward package that the frozen pilot could acquire (frozen
acquisition score 18.92, above 30 of 40 pool cards) activated **once in 400 Dusk runs**, because the
pilot has no term for it and `shatterDusk = 86.15` orders every play. Shipping S1–S3 without S4
reproduces that result exactly.

Minimum shape:

- `card_score` (`balance_pilot.gd:274-341`): one arm valuing `wardBurst` as `spend * per`, i.e. on the
  same scale the `dmg` arm already uses.
- `_combat_score` (`balance_pilot.gd:153-193`): one arm that values playing the cash-out when
  `player.block` exceeds both the gate and the previewed incoming damage — the surplus-Ward
  condition. Reuse `_incoming` (`balance_pilot.gd:229`); add no new forecast.
- This is a **new pilot identity** (e.g. `p9-w0-v1`) and must be declared as such.

Scientific obligations attached to S4, without which it is candidate-tuning:

1. The term and its weights are frozen **before** any row is executed, in the preregistration.
2. A **null-card control** runs the same new pilot identity against unchanged current-main content.
   The destination must read 0 there; the term alone must not manufacture activation.
3. **Policy-sensitivity witnesses:** the destination must reach its floor under at least two
   materially different policy settings, not only the tuned one, per #421 acceptance.

## 3. Content shape

Exactly **one** new card is strictly necessary — the cash-out. Ward generation already exists
(`defend`, `brace`, `deflect`, `sidestep`, `bulwark`, `aegis`, `fortify`, `flawlessForm`,
`metallicize`, `barricade`), and adding generation would move global defence for both aspects.

```json
"<cardId>": {
  "type": "skill",
  "aspect": "duskblade",
  "rarity": "uncommon | rare",
  "cost": 1,
  "target": "enemy",
  "requires": { "wardAtLeast": <N> },
  "effects": [ { "kind": "wardBurst", "spend": <N>, "per": <D> } ],
  "name": "...", "text": "...", "vfx": "...",
  "up": { "effects": [ { "kind": "wardBurst", "spend": <N>, "per": <D'> } ], "text": "..." }
}
```

Note on `type`: it must be **`skill`**. An `attack`-typed cash-out would earn the implicit chip
(`combat.gd:814`) and re-couple the new destination to shatter, defeating its purpose. This is the
single most important content decision in this spec.

`<N>` and `<D>` are **not** proposed here. They must be frozen in the preregistration before rows,
together with the pool tier, using the existing pool as the anchor (`aegis` gives 30 Ward for 2;
`oblivionStrike` deals 30 for 3). A first-order sanity target is that a full cash-out is comparable to
a rare attack, not to a shatter chain.

Hydration is mandatory and gated: English and Traditional-Chinese lines for `name`, `text` and the
upgrade text, plus `tools/check_locale_coverage.py` and `tools/check_locale_font_coverage.py` — a new
zh-Hant glyph fails a CI-only cmap gate unless the Noto Serif TC subset is rebuilt.

## 4. Invariants this spec must not touch

- **Stun stays bundled.** `_shatter_enemy` (`combat.gd:685-714`) is not edited. Nothing outside it
  sets `e.staggered`.
- **H10** — `apply_chips` stays Dusk-only; the new kind creates no chip on any path.
- **H11** — the new kind applies no status of any kind, and no Smolder. (Note B1 in
  `design-verdict-v1.md`: the H11 *observer* is independently broken on current-main content and must
  be resolved by Ash before any Phase A, regardless of this spec.)
- **Save and identity** — Ward/`block` is combat-scoped and already ephemeral; the new kind adds no
  persistent field. No save version bump, no migration, no internal-ID change, no protected-seed use.
- **Determinism** — no `rng` call anywhere in S1–S3; the run RNG stream must be untouched, so replay
  identity holds.
- **Goldens** — no existing card carries `requires`, `aspect` or `wardBurst`, so `port_fixtures/`
  goldens must remain byte-identical. Any drift is a defect in the change, not a golden to update.
- **`outcomeDigest`** — the new `wardSpend` event is presentation/observation only and must be
  excluded, as EP4's readout output was.

## 5. Smallest decisive proof set

Zero-row, before anything else:

1. `tools/check_imports.sh`, `tools/check_scripts.sh`.
2. `godot --headless -s res://tests/run_all.gd` — full suite green, `port_fixtures/` unchanged.
3. New unit coverage, one assertion each: gate blocks below threshold and allows at threshold;
   `spend` decrements Ward by exactly `spend`; damage equals `spend * per` and is unaffected by
   `str`, `weak` and enemy `vulnerable`; **no chip and no shatter is produced by the cash-out**;
   aspect 1 produces no state write and no event; unknown `requires` key fails closed in
   `ContentDB` validation; RNG state identical before and after a cash-out.
4. A replay-identity check on an existing recorded run: unchanged.

Only then, and only under a separate Ash authority: preregistration, null-card control, and one
Phase A on the frozen identities.

## 6. Kill criteria

Stop and report, do not repair in place, if any of these appear:

- any `port_fixtures/` golden drifts;
- any RNG-state or replay divergence on unchanged content;
- any `wardSpend` event, or any behavioural difference at all, on an Ashwarden row;
- the null-card control shows non-zero activation (the policy term is manufacturing the destination);
- the change requires a second effect kind, a status, a `_shatter_enemy` edit, or a per-card branch in
  `can_play` — that is the signal the minimum has been exceeded and the design must return to Ash.

## 7. Explicit non-goals for Codex

Do not implement anything in this file yet. Do not add allEnemies cash-out, Ward-scaling relics,
a Ward cap, Ward carry-over between turns, a second card, a new art, or a detector change. Do not
touch `_shatter_enemy`, Stun, `apply_chips`, existing card values, `docs/`, or product `main`.
Do not open a branch, PR or Actions run.
