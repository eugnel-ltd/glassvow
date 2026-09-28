#!/usr/bin/env python3
"""Deterministic re-implementation of BalancePolicy p8-d0-v1 card_score
(tools/balance_pilot.gd:274-329) for zero-row acquisition arithmetic.
No Godot process, no simulator row, no RNG. Self-checked against the frozen
weights in tools/balance_policy.gd:5-64."""
import json, sys

W = {
 "card": {"rarity": {"starter":0,"common":4.5915674100619,"uncommon":4.8437263622436255,"rare":6.99049021397807},
   "blockHeal":0.847886087458699,"drawEnergy":10.03605729808525,"chipDusk":6.7617601186515,
   "chipAsh":2.2778339702244352,"ember":2.16564561226858,"loseHp":0.38116165561253,
   "power":6.5654367491250945,"aspectBonus":7.27725827486158},
 "status": {"poisonDusk":0.20213950910252398,"poisonAsh":0.779955671227815,
   "vulnerableDusk":10.4961529566287,"vulnerableAsh":3.70383807935751,"weak":5.51631708339288,
   "str":7.49465968032341,"dex":5.549792717976205,"regen":11.76985144414705,
   "venomousDusk":5.79026208118971,"venomousAsh":18.9127656174971,"ritual":6.526393909972665,
   "barricade":8.37046439591552,"beaconDusk":10.4626743871535,"beaconAsh":4.120495069530225,
   "nightsight":7.86991789675343},
 "special": {"catalystDusk":5.731335081503705,"catalystAsh":31.1169328405239,
   "shatterEchoDusk":14.4155518047532,"shatterEchoAsh":7.3614481384374955,"execute":10.7156203095633,
   "leech":14.3692959512496,"doubleBlock":7.67567992016291,"pyreTithe":5.52944612840346,
   "fallback":7.51102251855123},
}
DUSK_BONUS = ["eclipseSlash","chisel","warCry","limitBreak","resonantLance","executioner"]
ASH_BONUS  = ["ashBite","smother","venomStrike","toxicMist","ashenChoir","catalyst","virulence","annihilate"]

def status_value(i, n, dusk):
    if i == "poison":   return n*(n+1) * (W["status"]["poisonDusk"] if dusk else W["status"]["poisonAsh"])
    if i == "vulnerable": return n * (W["status"]["vulnerableDusk"] if dusk else W["status"]["vulnerableAsh"])
    if i == "weak":     return n*W["status"]["weak"]
    if i == "str":      return n*W["status"]["str"]
    if i in ("dex","metallicize"): return n*W["status"]["dex"]
    if i == "regen":    return n*W["status"]["regen"]
    if i == "venomous": return W["status"]["venomousDusk"] if dusk else W["status"]["venomousAsh"]
    if i == "ritual":   return n*W["status"]["ritual"]
    if i in ("barricade","energized"): return W["status"]["barricade"]
    if i == "beacon":   return W["status"]["beaconDusk"] if dusk else W["status"]["beaconAsh"]
    if i in ("nightsight","emberflow"): return W["status"]["nightsight"]
    return 0.0   # thorns, frail, rampage -> literal zero

def special_value(i, dusk):
    if i == "catalyst":   return W["special"]["catalystDusk"] if dusk else W["special"]["catalystAsh"]
    if i == "shatterEcho":return W["special"]["shatterEchoDusk"] if dusk else W["special"]["shatterEchoAsh"]
    if i in ("execute","momentum"): return W["special"]["execute"]
    if i in ("leech","devour","phantom"): return W["special"]["leech"]
    if i in ("doubleBlock","flawless","emberNova"): return W["special"]["doubleBlock"]
    if i in ("pyreTithe","emberdance"): return W["special"]["pyreTithe"]
    return W["special"]["fallback"]

def card_score(d, dusk, cid=""):
    s = W["card"]["rarity"].get(d.get("rarity","starter"), 0) - float(d.get("cost",0) or 0)
    for fx in d.get("effects", []):
        k = fx.get("kind","")
        n = float(fx.get("n",0) or 0)
        if k == "dmg":  s += n*float(fx.get("times",1))
        elif k in ("block","heal"): s += n*W["card"]["blockHeal"]
        elif k in ("draw","energy"): s += n*W["card"]["drawEnergy"]
        elif k == "chip": s += n*(W["card"]["chipDusk"] if dusk else W["card"]["chipAsh"])
        elif k == "ember": s += n*W["card"]["ember"]
        elif k == "loseHp": s -= n*W["card"]["loseHp"]
        elif k == "status": s += status_value(fx.get("id",""), int(n), dusk)
        elif k == "special": s += special_value(fx.get("id",""), dusk)
    if d.get("type","") == "power": s += W["card"]["power"]
    s += float(d.get("chip",0) or 0)*(W["card"]["chipDusk"] if dusk else W["card"]["chipAsh"])
    if dusk and cid in DUSK_BONUS: s += W["card"]["aspectBonus"]
    if (not dusk) and cid in ASH_BONUS: s += W["card"]["aspectBonus"]
    return s

def demo():
    """Self-check: three hand-computed anchors from the frozen weights."""
    assert abs(card_score({"rarity":"common","cost":2,"effects":[{"kind":"dmg","n":12}]}, True) - (4.5915674100619-2+12)) < 1e-9
    assert abs(card_score({"rarity":"rare","cost":1,"type":"skill","target":"allEnemies",
                           "effects":[{"kind":"chip","n":2}]}, True, "limitBreak")
               - (6.99049021397807-1+2*6.7617601186515+7.27725827486158)) < 1e-9
    assert status_value("thorns", 9, True) == 0.0
    return "PASS (3 checks)"

if __name__ == "__main__":
    print(demo())
    c = json.load(open("content/full-content.json"))
    pool = [i for t in ("common","uncommon","rare") for i in c["cardPools"][t]]
    rows = sorted(((card_score(c["cards"][i], True, i), i) for i in pool), reverse=True)
    print("\n-- frozen Dusk pool acquisition ranking (p8-d0-v1 card_score) --")
    for s, i in rows: print(f"{s:8.2f}  {i}")
    cand = {
      "A1 skill dmg 12 (chip-free burst, common)": {"rarity":"common","cost":1,"type":"skill","target":"enemy","effects":[{"kind":"dmg","n":12}]},
      "A2 skill emberNova (rare)": {"rarity":"rare","cost":1,"type":"skill","target":"enemy","effects":[{"kind":"special","id":"emberNova","n":3}]},
      "A3 thorns power 4 (uncommon)": {"rarity":"uncommon","cost":1,"type":"power","target":"self","effects":[{"kind":"status","who":"self","id":"thorns","n":4}]},
      "A4 ward pile: block 14 skill (uncommon)": {"rarity":"uncommon","cost":1,"type":"skill","target":"self","effects":[{"kind":"block","n":14}]},
      "A5 ward+draw skill (common)": {"rarity":"common","cost":1,"type":"skill","target":"self","effects":[{"kind":"block","n":8},{"kind":"draw","n":1}]},
      "EP4 mirrorEdge (measured 1/200)": {"rarity":"common","cost":1,"type":"attack","target":"enemy","effects":[{"kind":"dmg","n":6},{"kind":"block","n":11}]},
    }
    print("\n-- STREAM A candidate shapes --")
    for k, d in cand.items():
        print(f"dusk={card_score(d,True):8.2f}  ash={card_score(d,False):8.2f}  {k}")
