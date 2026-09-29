# The Ways of a Class — design template

**Status:** active template, 2026-09-29. Owner: James. Derived from the Duskblade lock in [`README.md`](README.md). Use it for every class: the Ashwarden in 1.1, and any later aspect.

A class has three **ways**: three strategic languages a player discovers by playing, never chooses from a menu. The only gauge is the lantern's flame. Power comes from the cards' own synergy, one capstone per way and one crown per way. The flame changes only the lantern's quality, identically for every way, so it can never decide which way wins.

## 1. Content schema

Everything below is content data. No way, colour or threshold lives in code.

```json
{
  "aspects": [
    {
      "id": "<aspect id>",
      "ways": [
        {
          "id": "<way id>",
          "name": "<en name>",
          "nameZh": "<zh-Hant name>",
          "flame": { "colour": "#rrggbb", "shape": "tongues | round | tall" },
          "crown": "<boss relic id>",
          "crownAlts": ["<boss relic id>", "..."],
          "capstones": ["<rare card id>", "..."],
          "deed": "<deed id>",
          "affinity": { "<card id>": 1.0, "<duo card id>": 0.5 },
          "relics": { "<relic id>": 1.0, "<duo relic id>": 0.5 }
        }
      ],
      "flame": {
        "minMass": 5, "steadyMin": 0.60, "trueMin": 0.80,
        "sootMass": 6, "sootMax": 0.45, "fringeMin": 0.25,
        "likeWeight": 1.5, "fringeWeight": 1.2,
        "lantern": {
          "sootLeak": 1, "sootArtCost": 1,
          "steadyCap": 2, "steadyFirstGain": 1, "trueArtCost": 1
        }
      },
      "sootCrown": "<boss relic id>",
      "excludes": { "cards": ["..."], "relics": ["..."] }
    }
  ]
}
```

Rules of the schema:

- Affinity weights are 0.5 or 1.0. A card with two 0.5 entries is a **duo** card and bridges two ways.
- A card absent from every way is **clear glass**: fuel, never noise. Ward, plain draw and plain damage are usually clear.
- `excludes` lists the other classes' language that would be dead glass here. Nothing is deleted from content.
- `flame` constants are per aspect so a class can feel different, but start from the Duskblade values.
- The purity function, tiers, recognition at the boss and like-calls-to-like are the same code for every aspect (`domain/rules/flame.gd`, `rewards.gd`).
- `flame.lantern` is the lantern's quality (lock §5), read from the flame at combat start: Soot loses `sootLeak` Embers at the end of each of the player's turns and adds `sootArtCost` to the Art's price; Steady and True add `steadyCap` to the Ember cap and `steadyFirstGain` to each turn's first Ember gain; True also takes `trueArtCost` off the Art, never below 1. Every knob is a whole number of at least 0, and a missing knob is 0, the plain lantern. The same code serves every aspect (`domain/rules/combat.gd`). *Implementation note (lock PR 4, 2026-09-29): these names replace the per-tier `soot`, `steady` and `true` blocks first sketched here.*

## 2. Design checklist

Work through it in order. Each step has a stop rule.

1. **Three verbs.** Read the class blurb. It should already name three things the class does. If it names one, the class is not ready for ways; write the blurb first. Duskblade: strikes, shatters, fuel.
2. **Seeds in the starter deck.** The starter deck carries exactly one card of each way. Everything else in it is clear glass. If a way has no seed, add one and remove a Strike.
3. **Affinity table.** Tag every card in the class's reachable pool: 1.0, 0.5 or clear. Count coloured cards per way under a **fresh** pool (no deeds, no waves) and a **full** pool. Target: four to five fresh, about ten full, per way.
4. **Exclusions.** List the other classes' dead glass for this class.
5. **Crowns and capstones.** One boss crown per way, one soot crown for the class, at least one rare capstone per way, and at least one duo card for each pair of ways. Where one is missing, that is the content lane's list.
6. **Deeds.** One deed per way, driven by a stat the way produces, unlocking that way's depth. Add the stat to `run.stats` if it does not exist.
7. **Flame.** Three colours and three shapes, distinct at a glance and under colour-blindness. A soot look for the class.
8. **Lines.** Six lines: the lighting line, first Steady, first True, first Soot, the Vigil whisper after a Soot death, first fringe. In the class's register. No mechanic words. Three codex sentences, one per colour, revealed after first Steady in that colour.
9. **Readout.** Committed arms for each way plus adaptive plus random, both pool states, both gated vows, paired seeds. Gates G1–G7 and the human round H as in the Duskblade lock §11. Calibrate lantern knobs in the lock's order.
10. **Fallback.** If a third way cannot reach G1 and G2 within the time box, ship two clear ways and let the third be a fringe. Say so in the release notes to yourself, not to the player.

## 3. Ashwarden sketch (not decided; for 1.1)

The blurb: *"Smoke given a shape. Lets the Smolder do the killing and kindles its own hand to feed the lantern. Slower, but it endures."* Three verbs are already there.

| Way | Working name | Verbs | Existing glass |
|---|---|---|---|
| 燼 Smolder | Ashsmoke | Smolder, Emberfang, Catalyst, the fire that leaps | venomStrike, toxicMist, annihilate, catalyst, virulence, ashenChoir; ashenCore, smolderingCoal; Ashfall |
| 燃 Hand | Kindled Hand | Kindle, draw, hand size, feed the lantern | preparation, surge, offering, tithe, pyreheart, emberdance; verdantBranch, crownOfTithes; the hand-size payoff of #544 |
| 忍 Endure | Ashen Wall | Ward, Poise, heal, regen, outlast | bulwark, fortify, ironSkin, regrowth, bastion, flawlessForm, aegis; gravebloom, sunBlossom, wardingCharm, basaltIdol |

Starter deck check: ashBite ×4 (Smolder), smother ×2 (Endure?), firstSpark (Hand). Confirm smother's affinity when the class is designed. Excludes for the Ashwarden: the Duskblade's Chip and Shatter glass (chisel is a starter, so this is about uppercut, quakeblow, oblivionStrike, limitBreak, resonantLance and shatterersCrown, bellOfEndings, prismCharm), since Shatter is Duskblade-only in `combat.gd`.

Nothing here is a decision. It shows the template producing a first draft in minutes, which is the point of having one.
