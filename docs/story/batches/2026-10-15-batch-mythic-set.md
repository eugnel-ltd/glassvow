# Mythic set — copy batch (#212)

Status: **PROMOTED — all six story checks passed; ready for lane 2 wiring**. Source: the merged [mythic design](../../design/2026-10-15-mythic-set/README.md), sections 1, 3.5, 4 and 9, at `43e94789f970c71fdf96c7705339d8186b98bbc3`.

## Contract

Six names, base and upgraded rules, six lore fragments, four narration lines across `knight-2` and `knight-3`, and `ui.rarity.mythic`. All narrative copy is L1, including The Unbroken Flame after its Act IV unlock. zh-Hant is the source; English is rewritten prose. Rules and rarity labels disclose mechanics, not narrative truth.

Authority: `00-truth.md`, `02-cast.md` (Wounded Knight), `04-delivery.md`, `06-glossary.md`, `docs/zh-hant-glossary.md`, and ledger rows 1, 9–14, 20, 303 and 377–380. No new canon, whisper, Keeper line or Knight dialogue. Rows 377–380 remain unchanged. The monument's identity remains unconfirmed.

This batch promotes copy for lane 2 to wire. It does not change `content/`, `locale/`, code or assets. The names remain the design's six picks; the owner may re-pick them. No new audio is requested: use the host scene's existing soundscape. Narration below is visible text, not spoken dialogue.

## Line table

Columns retain the delivery schema. Empty selection metadata means that the card field or scene beat selects the line directly; it does not create a new runtime pool. Card `desc.up` rows supply complete upgraded descriptions. Cost-only upgrades repeat the base description. Unbowed has no upgrade. The narration IDs identify ordered beats for lane 2, not newly reserved runtime IDs.

| id | speaker | slot | conditions | priority | once | cooldown_runs | weight | zh | en | asserts |
|---|---|---|---|---|---|---|---|---|---|---|
| bankedFire.name | — | card.name | card present | | | | | 封火 | Banked Fire | L1; sheltered coal; no owner named |
| bankedFire.desc | — | card.rules | base | | | | | 獲得 1 點餘燼。若本場戰鬥獲勝，提燈的餘燼會保留至下一場戰鬥。 | Gain 1 Ember. If you win this fight, carry your lantern's Embers into the next fight. | Mechanical; victory only; remaining Embers |
| bankedFire.desc.up | — | card.rules | upgraded | | | | | 獲得 2 點餘燼。若本場戰鬥獲勝，提燈的餘燼會保留至下一場戰鬥。 | Gain 2 Embers. If you win this fight, carry your lantern's Embers into the next fight. | Mechanical; victory only; remaining Embers |
| bankedFire.lore | unattributed | card.lore | card revealed or inspected | | | | | 仍有餘溫。風吹不到碑腳。 | Still warm, sheltered at the foot of the monument. | L1; ordinary residual heat; no surviving personal will asserted |
| silvering.name | — | card.name | card present | | | | | 鍍銀 | Silvering | L1; mirror craft |
| silvering.desc | — | card.rules | base; cost 2 | | | | | 選擇一名敵人。它下一次行動時，原本對你造成的傷害與施加的狀態改由它承受，也不會往你的牌堆加入牌。燃燼。 | Choose an enemy. On its next action, any damage and harmful effects meant for you are redirected to it. It adds no cards to your piles. Kindle. | Mechanical; waits through Stagger; self-buffs unchanged |
| silvering.desc.up | — | card.rules | upgraded; cost 1 | | | | | 選擇一名敵人。它下一次行動時，原本對你造成的傷害與施加的狀態改由它承受，也不會往你的牌堆加入牌。燃燼。 | Choose an enemy. On its next action, any damage and harmful effects meant for you are redirected to it. It adds no cards to your piles. Kindle. | Mechanical; cost-only upgrade |
| silvering.lore | unattributed | card.lore | card revealed or inspected | | | | | 鏡子從不先動。這一次，它把那一擊還了回去。 | A mirror never strikes first. This one returned the blow. | L1; reflection on surface; no identity behind glass confirmed |
| unbrokenFlame.name | — | card.name | card present | | | | | 未碎之火 | The Unbroken Flame | L1; surface legend of one fire |
| unbrokenFlame.desc | — | card.rules | base; cost 2 | | | | | 本場戰鬥中，無論提燈燃着哪一種火，每一種火色效果都會生效。 | For this fight, all flame effects are active, whatever colour your lantern burns. | Mechanical; no change to flame reading, tier or lantern quality |
| unbrokenFlame.desc.up | — | card.rules | upgraded; cost 1 | | | | | 本場戰鬥中，無論提燈燃着哪一種火，每一種火色效果都會生效。 | For this fight, all flame effects are active, whatever colour your lantern burns. | Mechanical; cost-only upgrade |
| unbrokenFlame.lore | unattributed | card.lore | card revealed or inspected | | | | | 成為六片之前，它是一團。 | Six pieces. Once, a single fire. | L1; surface legend; neither cause of fracture nor door condition |
| unbowed.name | — | card.name | card present | | | | | 不臥 | Unbowed | L1; refusal to yield |
| unbowed.desc | — | card.rules | no upgrade | | | | | 無法打出。若此牌未被燃燼，每場戰鬥中你首次將要倒下時，你仍然站着：直到你下一個回合結束前，你不會失去生命，也不能打出令你失去生命的牌。屆時若生命為 0，你才倒下。 | Unplayable. Unless you have Kindled this card, the first time each fight you would fall, you stay standing. Until the end of your next turn, you cannot lose HP or play cards that make you lose HP. If you still have 0 HP then, you fall. | Mechanical; once per fight; next-turn deadline; HP-payment guard |
| unbowed.lore | unattributed | card.lore | card revealed or inspected | | | | | 有些人，始終沒有躺下。 | Some never lay down. | L1; courage or standing death; no monument equivalence |
| knownRoad.name | — | card.name | card present | | | | | 熟路 | The Known Road | L1; familiarity |
| knownRoad.desc | — | card.rules | base; cost 3 | | | | | 本場戰鬥中，每個回合開始抽牌時，你可以用抽牌堆的牌替換本次抽到的牌，張數不變。 | For this fight, when you draw at the start of a turn, you may swap the cards dealt for cards in your draw pile. Keep the same number of cards. | Mechanical; normal deal is default; no discard pick or extra draw |
| knownRoad.desc.up | — | card.rules | upgraded; cost 2 | | | | | 本場戰鬥中，每個回合開始抽牌時，你可以用抽牌堆的牌替換本次抽到的牌，張數不變。 | For this fight, when you draw at the start of a turn, you may swap the cards dealt for cards in your draw pile. Keep the same number of cards. | Mechanical; cost-only upgrade |
| knownRoad.lore | unattributed | card.lore | card revealed or inspected | | | | | 你記得走過這段路。記得很清楚。 | You remember this road. Every step of it. | L1; remembered experience, not a claim that this body walked |
| cleanBreak.name | — | card.name | card present | | | | | 無痕 | Clean Break | L1; glazier's craft |
| cleanBreak.desc | — | card.rules | base | | | | | 造成 @8@ 點傷害。額外琢擊 2 格璃面。本場戰鬥餘下時間，敵人碎裂後不再增加璃面。 | Deal @8@ damage. Chip 2 extra Facets. For the rest of this fight, enemies no longer gain a Facet when they shatter. | Mechanical; all enemies; permanent for this fight |
| cleanBreak.desc.up | — | card.rules | upgraded | | | | | 造成 @11@ 點傷害。額外琢擊 3 格璃面。本場戰鬥餘下時間，敵人碎裂後不再增加璃面。 | Deal @11@ damage. Chip 3 extra Facets. For the rest of this fight, enemies no longer gain a Facet when they shatter. | Mechanical; full upgraded text; identical damage markup across locales |
| cleanBreak.lore | unattributed | card.lore | card revealed or inspected | | | | | 切口很乾淨。看不出舊痕。 | A clean edge. Nothing to show where it broke before. | L1; visible trace only; no cutting-erases-memory law |
| knight-2.1 | narrator | knight-2 beat 2 | route meeting 2 | | | | | 石柱前那座碑仍在。 | The monument still stands at the foot of the pillar. | L1; row 380's two readings remain open |
| knight-2.2 | narrator | knight-2 beat 4 | route meeting 2 | | | | | 風吹不到碑腳。那一點火，沒有被吹走。 | In the monument's shelter, one ember still glows. | L1; visible shelter; no personal will retained here |
| knight-3.1 | narrator | knight-3 beat 2 | route meeting 3 | | | | | 它還在。 | Still there. | L1; visible ember is the referent |
| knight-3.2 | narrator | knight-3 beat 4 | route meeting 3 | | | | | 仍有餘溫。 | Still warm. | L1; surface warmth only |
| ui.rarity.mythic | — | ui.rarity | rarity label | | | | | 秘藏 | Mythic | Mechanical; glossary term |

## Scene context (not new player-facing text)

`knight-2`: show the shattered pillar and the monument at its foot; wind carries ash west. Show the ember in the monument's lee before beat 4. `knight-3`: show that same shelter and the ember with its ash fallen away; after beat 2, lift the ember into the lantern and reveal Banked Fire, then show beat 4. No scene calls the monument the Knight's. No Knight speech is added. No new audio asset or spoken track is required.

## Canon decision

The design's reading, “what he kept from the wind outlasts him”, is **not promoted**. These lines establish heat and shelter only. They neither identify whose fire it is nor retain a person's will at the monument. Ledger row 303's westward return remains intact. After the twist, the monument may be understood as the Knight's only body; the ember's origin and metaphysical status remain unstated. This is a rereading of the standing shelter, not a new claim about the fire.

Clean Break likewise describes an unmarked edge, not a new way to destroy memory. Its title and fragment evoke the existing glass/memory motif without deriving a new physical law from it.

## Changes from the design draft

- All six names and the rarity label are retained.
- Banked Fire rules now say **win**, matching section 1.2. Its English lore is a fresh sentence about warmth and shelter.
- Silvering rules specify redirected damage and effects plus suppressed pile additions; they do not promise to redirect its own buffs. The final English wording makes the redirection conditional on an effect being meant for the player, so a buff-only action does not imply an attack. Its English fragment uses a reflected blow rather than literal movement.
- The Unbroken Flame rules state the fight duration. Its English fragment is rewritten around the visible six-to-one contrast.
- Unbowed retains the full protection and HP-payment guard. English is split into short sentences; its fragment omits an unsupported antecedent for “them”.
- The Known Road rules describe the default deal and optional swaps, preserving section 1.6's same-size choice. Its lore anchors certainty in memory rather than asserting that the present body walked.
- Clean Break's upgraded rules are expanded in full. Its lore replaces “it cannot remember” with an absence of visible marks; clean cutting does not become a new canon mechanism.
- The four zh narration lines are retained. English is rewritten to the on-screen beats. The ember line avoids assigning the ember to anyone.

## Font handoff

The existing locale corpus passes `python3 -B tools/check_locale_font_coverage.py`. Running the same checker with `--line-table` against the 28 bilingual rows extracted from this table fails on these additional characters:

`乾` U+4E7E, `些` U+4E9B, `吹` U+5439, `哪` U+54EA, `屆` U+5C46, `很` U+5F88, `楚` U+695A, `淨` U+6DE8, `熟` U+719F, `臥` U+81E5, `舊` U+820A, `論` U+8AD6.

Lane 2 must rebuild the bundled subsets after wiring the promoted copy, then pass the normal font gate. This batch does not change fonts. Do not replace the selected words to conceal a missing glyph.

## Review record

Each pass uses a fresh-context Sonnet agent and a distinct hypothesis. All 28 rows are covered in both languages where the hypothesis applies.

| Pass | Hypothesis | Result |
|---|---|---|
| Truth and matrix | A line asserts new canon, exceeds speaker knowledge or misstates the design's rule. | PASS; no new facts, personal fire ownership or memory-erasure physics. |
| Vocabulary and orthography | A line violates the canonical glossary, HK register, 着/裏 or the full seven-term vertical ban. | PASS, including the additional Knight-scene prohibitions. |
| Voice and English native read | A line gains an unlicensed speaker or uses unnatural translated syntax. | PASS after correcting both Silvering descriptions, then making their redirection conditional on effects meant for the player; the original reviewer verified the final wording. |
| Ladder and ledger | A narrative line lacks its dual-reading entry or exceeds the channel ceiling. | PASS; all 16 narrative items match rows 472–481 and remain L1, with supported rereadings. |
| Twist safety | Combined clues force one hidden reading before the reveal, or fail after it. | PASS for all 16 narrative items in both languages and their cumulative reading; row 303 remains intact and row 380 keeps both readings. |
| Adversarial blocker verification | An unresolved acceptance or semantic defect prevents promotion. | PASS after making Silvering's redirection conditional on damage/effects meant for the player; the reviewer verified both corrected lines verbatim. Buff-only actions remain valid. |

Deterministic checks: 28 unique bilingual rows with no empty language leaf; damage-markup parity; seven-term and Knight-token scans; protected ledger rows 303 and 377–380 byte-identical to the base. The CI classifier selects documentation only. All 37 classifier tests, citation freeze, privacy-site self-test (20 seeded defects), privacy-site currency and documentation anchors pass. Font coverage is the explicit lane-2 handoff above, not a claimed pass for the new copy.
