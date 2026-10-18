# Ashwarden flame — copy batch (#544 A7)

Status: **PROMOTED — four canon lenses and twist safety passed; no blockers required adversarial refutation.** Exact supplied bilingual selection: `docs/design/2026-10-05-ash-flame/README.md` §9 at `829e3eed4d1ff906c5adeff9dc9d1dcc5649cbdd`. No new dialogue or canon is drafted.

## Contract

Six lines and three codex sentences, all L1. The first Keeper remark belongs to the Vigil's first Ash setting-out through the existing `hearth:start` beat; the universal opening law stays unchanged. Four tier/fringe whispers use the existing transition slots and class-qualified once IDs. The Ash Soot-death row also covers legacy runs saved before class deferral; an evenly mixed Ash deck can read Soot. Codex sentences unlock only after their actual colour reads Steady or True. The Unbroken Flame activates riders only and must not fabricate a flame reading or reveal another class's colour. Aspect 1 is the existing Ashwarden index, not a new content or save ID.

## Line table

| id | speaker | slot | conditions | priority | once | cooldown_runs | weight | zh | en | asserts |
|---|---|---|---|---|---|---|---|---|---|---|
| flame.ashwarden.hearth | keeper | hearth | aspect=1 | 1 | true | 0 | 1 | 它燒得慢，燒得久。 | It burns slow, and it burns long. | L1 |
| flame.ashwarden.steady | walker | flame.steady | aspect=1 | 0 | true | 0 | 1 | 灰下的火，認得你了。 | Under the ash, the fire knows you now. | L1 |
| flame.ashwarden.true | walker | flame.true | aspect=1 | 0 | true | 0 | 1 | 別的都燒成了灰，只剩一種火。 | Everything else has burned to ash. One fire is left. | L1 |
| flame.ashwarden.soot | walker | flame.soot | aspect=1 | 0 | true | 0 | 1 | 煙多於火。 | More smoke than fire. | L1 |
| flame.ashwarden.sootDeath | walker | flame.sootDeath | aspect=1 | 0 | true | 0 | 1 | 你的火從來只有煙。 | Your fire was only ever smoke. | L1 |
| flame.ashwarden.fringe | walker | flame.fringe | aspect=1 | 0 | true | 0 | 1 | 煙裏有另一種顏色。 | There is another colour in the smoke. | L1 |
| codex.lantern.smolder | keeper | codex.lantern.smolder | aspect=1 | 0 | true | 0 | 1 | 灰綠的火伏得低，在灰下燒得最久。 | An ash-green fire lies low, and lasts longest under the ash. | L1 |
| codex.lantern.hand | keeper | codex.lantern.hand | aspect=1 | 0 | true | 0 | 1 | 明黃的火分出許多火尖，像一隻手；手裏握着的越多，它燒得越亮。 | A candle-yellow fire parts into many tips, like a hand; the more the hand holds, the brighter it burns. | L1 |
| codex.lantern.endure | keeper | codex.lantern.endure | aspect=1 | 0 | true | 0 | 1 | 珠光的火又直又靜，風來了也不倒。 | A pearl fire stands straight and still, and does not fall when the wind comes. | L1 |

## Dual readings

| id | surface | post-twist | level | leak risk |
|---|---|---|---|---|
| flame.ashwarden.hearth | This lantern burns slowly and lasts | What burns is the walker's will (00 §3.2): a slow fire is a long dying, and the arrangement is served longest by a walker who lasts | L1 | Low; metaphor only, no fission or identity stated. |
| flame.ashwarden.steady | The flame has taken your colour | The hearth's fire is the first fire's embers under the ash that drifted west (00 §2.2); every walker who carried it was you, so it knew you already (as row 459) | L1 | Low; metaphor only, no fission or identity stated. |
| flame.ashwarden.true | One kind of glass; one clean fire | Ash is will burned out (00 §8.6): the walker has spent everything but one fire, and the door wants one whole fire (00 §2.2, §2.6) | L1 | Low; metaphor only, no fission or identity stated. |
| flame.ashwarden.soot | A scattered deck burns poorly | A will spread thin gives off more than it burns; it lights nothing (as row 462) | L1 | Low; metaphor only, no fission or identity stated. |
| flame.ashwarden.sootDeath | This run's flame never took | The walker went out before the fire took hold: a death in smoke, read at the hearth by the one who stayed | L1 | Low; metaphor only, no fission or identity stated. |
| flame.ashwarden.fringe | A second way shows at the edge | The other colour is also you; there is no one else in the Queue (as row 460) | L1 | Low; metaphor only, no fission or identity stated. |
| codex.lantern.smolder | The Smolder fire is slow and patient | The fire that lasts longest under the ash is the hearth's own: it never left the hearth (00 §2.4) | L1 | Low; metaphor only, no fission or identity stated. |
| codex.lantern.hand | The more a Hand deck holds, the stronger | The lantern burns what the walker carries: the more it holds, the more there is to burn | L1 | Low; metaphor only, no fission or identity stated. |
| codex.lantern.endure | The Endure flame cannot be put out | The walkers die standing and do not lie down (row 1, L1) | L1 | Low; metaphor only, no fission or identity stated. |

The pearl surface describes the flame's shape and resistance to wind; it does not promise player immortality. Ledger rows 482–490 carry these exact bilingual lines and readings. New colour terms 灰綠 / ash-green, 明黃 / candle-yellow, 珠光 / pearl are ordinary descriptions, with glossary entries. The source lock's metaphor readings do not add fire physics or assign new knowledge to speakers.

## Review record

Native Claude/Sonnet tooling is unavailable (`command -v claude` has no result). The documented fresh-context fallback is mapped to two isolated Codex agents with no author history, no provider API calls, and no native Sonnet attribution. Four canon lenses are reported separately by the first agent. The second performs twist safety, then adversarially verifies any returned blockers against the bible. The selected nine lines are promoted unchanged; no new canon is settled.


| Pass | Distinct hypothesis | Result |
|---|---|---|
| Truth and matrix | Canon contradiction, invented physics or speaker knowledge beyond the matrix. | PASS; findings `[]`. |
| Vocabulary and orthography | Seven Tier A bans, glossary drift, calque or HK register/着/裏 failure. | PASS; findings `[]`; colour glossary rows present. |
| Voice | Keeper lies, urges departure, claims personal road experience or loses the warm tired voice; whispers explain. | PASS; findings `[]`. |
| Ladder and ledger | Any line lacks its bilingual ledger row or exceeds L1/channel/ Shade weight. | PASS; findings `[]`; rows 482–490. |
| Twist safety | Any individual or combined clue fails either reading or forces hidden truth. | PASS; findings `[]` for all 18 language cells and combined clues. |
| Adversarial verification | A canon-lint/twist blocker survives attempted refutation. | No blockers submitted; confirmed/refuted/unverified/warnings all `[]`. |

The canon worker applied the four original workflow lens prompts separately; the twist worker had a separate fresh context and received the empty canon-blocker set only after its own pass. Reviewed draft SHA-256: `1be0e6a1405230d1cc88a2e44be9d1f81944dbb09cdf99568d89bda5cff69fee`. Supplied §9 source slice SHA-256: `4a953b7158b1701e5f316414309886e42e3dbb337160a42d102ffe1dcc4642dd`. Ordered `id,speaker,zh,en,level` payload SHA-256: `7cb97539bf89dc912a5966094751df48366b1537da57b67434516ec50e7da740`. Promotion changes status and this record only, not the reviewed copy, readings or terms.
