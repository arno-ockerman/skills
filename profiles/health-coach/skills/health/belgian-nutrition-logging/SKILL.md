---
name: belgian-nutrition-logging
description: "Use when de gebruiker logs meals, Herbalife products, Belgian supermarket foods, or food photos and wants practical macro tracking with Belgium-first nutrition data."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [nutrition, belgium, macros, herbalife, photo-logging, health]
    related_skills: [hermes-agent]
---

# Belgian Nutrition Logging

## Overview
This skill is for low-friction food logging focused on practical macro tracking for de gebruiker in Belgium. It prioritizes reliable nutrition data from product labels, Belgian or EU product pages, and clear photo-based estimation when exact data is unavailable.

Primary goals:
- keep daily tracking simple
- bias toward accurate protein counting
- maintain a running total versus de gebruiker's targets
- be transparent about uncertainty

Daily targets must be read from the user's private configuration; no personal calorie or protein targets are published in this skill.

## When to Use
Use when:
- de gebruiker sends ontbijt, lunch, avondeten, snacks, shakes, bars, or drinks
- de gebruiker sends a photo of packaged food and wants accurate macros
- de gebruiker mentions Herbalife products and wants exact or near-exact values
- de gebruiker wants a running day total and a practical next step

Do not use for:
- medical diagnosis
- allergy safety decisions when the label is unreadable
- rigid calorie perfectionism

## Data Priority Order
Always use the highest-confidence source available, in this order:

1. **User-provided package photo with readable nutrition label**
2. **User-provided exact product name + serving size**
3. **Official Belgian / EU product page or manufacturer page**
4. **Reliable retailer page in Belgium / EU**
5. **Photo-based visual estimate** when no exact label/product data exists

If the source is not exact, say so clearly in one short sentence.

## Workflow
1. **Identify the food correctly**
   - Distinguish homemade meal vs packaged product.
   - For packaged foods, capture brand, flavour, pack size, and serving size.
   - For Herbalife, capture the exact product line and flavour if available.
   - If de gebruiker gives a product name without a label, treat that as sufficient to start lookup; do not ask for the label first.

2. **Choose the best source**
   - Default to **name-based lookup** for packaged foods when de gebruiker provides a recognizable product name.
   - If the label is visible in a photo, use vision first to read it.
   - If the label is not visible, use browser/web lookup for Belgium/EU-specific nutrition data.
   - Use the label/package photo as a precision upgrade, not as a requirement for logging.
   - If exact lookup fails, estimate from the photo or product type and label it as an estimate.

3. **Log the nutrition**
   Track at minimum:
   - kcal
   - protein
   - carbs
   - fat
   Also note when relevant:
   - vegetables/fruit
   - fiber
   - hydration

4. **Maintain a running day total**
   Keep a rolling total in the response for:
   - kcal
   - protein
   - carbs
   - fat

5. **Coach briefly**
   End with:
   - one thing that is going well
   - one practical improvement if useful
   - one next small step

## Herbalife Handling Rules
For Herbalife products:
- Prefer exact product labels or official product pages over generic memory.
- Watch for differences by market, flavour, and preparation method.
- For shakes, separate the powder from what it is mixed with when possible.
- If de gebruiker says only “Formula 1” or “PDM” without flavour/preparation, give a practical range and mark it as such.
- If a drink is low-calorie but marketed with extra claims, log the macros only and avoid health-claim hype.

## Belgian Supermarket / Snack Rules
For protein bars, yogurts, breads, ready meals, and drinks bought in Belgium:
- Start from the **product name** when de gebruiker gives one; do not require a label or package photo to begin logging.
- If a label photo is available, use it to verify or tighten the estimate.
- If the front-of-pack is shown but not the label, identify the exact product and only ask for the back label when precision truly matters.
- If the exact product can be found online, use the listed per-bar or per-serving values, not just per 100 g unless serving size is clear.
- If only per 100 g is available, calculate using the package weight and show that this was calculated.
- If no exact source is found, give a practical estimate and state that it is name-based rather than label-based.

## Photo Logging Rules
When de gebruiker sends a meal photo:
- identify likely protein source
- identify carb source
- identify fats/sauces
- identify vegetables/fruit
- estimate portion sizes conservatively
- state that photo estimates are approximations

When de gebruiker sends a packaged-food photo:
- first try to read the label
- if unreadable, identify product/brand/flavour from the front
- if still uncertain, give a range instead of pretending precision

## Response Format
For normal food logs, answer in this format:
- Log: ...
- Macro-inschatting: kcal ..., eiwit ..., koolhydraten ..., vetten ...
- Dagtotaal tot nu: kcal ..., eiwit ..., koolhydraten ..., vetten ...
- Goed: ...
- Beter/aanvullen: ...
- Volgende kleine stap: ...

If the nutrition values are exact from a label or official source, prefer:
- Macro-inschatting: **exact van label/officiële bron** — kcal ..., eiwit ..., koolhydraten ..., vetten ...

## Accuracy Rules
- Never claim exactness from a meal photo alone.
- Never invent flavour-specific product values.
- If precision is limited, use ranges.
- Track protein accurately against the privately configured target.
- Mention uncertainty briefly, without making logging annoying.

## Practical Coaching Lens
Interpret the day against the individual calorie and protein targets provided in private context.

Simple coaching defaults:
- If protein is low: suggest an easy protein addition.
- If calories are climbing fast: suggest a high-protein, low-calorie next choice.
- If vegetables/fiber are low: suggest one simple add-on.
- If recovery seems relevant: keep advice practical and non-extreme.

## Al gecontroleerde productwaarden (niet opnieuw opzoeken)

Deze zijn een keer exact van de productpagina of het label gehaald. Gebruik ze rechtstreeks en noem de bron in de notitie.

| Product | Waarde |
|---|---|
| Herbalife Formula 1 | 2 scheppen = 103 kcal / 9 g eiwit |
| Herbalife PDM | 2 scheppen = 65 kcal / 15 g eiwit (1 schep = 32,5 kcal / 7,5 g) |
| Herbalife24 Rebuild Strength | 1 dosering 50 g = **190 kcal / 25 e / 18 kh (14 suiker) / 1,5 vet** (EU-label) |
| Boni skyr (natuur) | per 100 g = **62 kcal / 11 e / 4 kh / 0,5 vet** (17,7 g eiwit per 100 kcal) |
| Boni pindakaas crunchy | per 100 g = **653 kcal / 23 e / 11 kh / 56 vet** |
| Boni appelcake | per 100 g = **401 kcal / 5,3 e / 36 kh / 12 vet** |
| Boni Breakfast Mix (diepvries fruit) | ~45 kcal per 100 g |
| Filet de Saxe (charcuterie) | per 100 g = **115 kcal / 25 e / 1 kh / 2 vet** — maar **2-5 g zout**: smaakmaker, houd het op 80-100 g |
| Cordon bleu (gepaneerd, Colruyt) | per 100 g = **~215 kcal / 14,5 e / 10 kh / 15 vet** |
| Magere melk (0,1%) | per 100 ml = **34 kcal / 3,4 e / 5 kh / 0,1 vet** |
| Griekse pasta (gekookt) | per 100 g = **158 kcal / 5,5 e / 31 kh / 1 vet** |

**Rekenles die hieruit volgt:** pindakaas is met 28 kcal per gram eiwit de duurste post in een ontbijt, cordon bleu (gepaneerd + kaas) kost ~15 g vet per 100 g. Als de gebruiker's eiwit klopt maar het vet boven 65 g uitkomt, zit het bijna altijd in deze drie: pindakaas, gepaneerde producten, cake/gebak. Kijk daar eerst.

**Eiwit-anker: 2 scheppen PDM haalt 40 g niet.** 2 scheppen = 15 g eiwit, dus een havermout-ontbijt met melk, chia en fruit eindigt op 30-32 g — dat patroon komt herhaald terug. Adviseer **3 scheppen als standaard** (39,6 g) of +100 g skyr, en zeg het één keer concreet in plaats van bij elke maaltijd opnieuw te rekenen.

Rebuild Strength is bedoeld voor anaerobe training van 45-60+ min; na een korte sessie is 190 kcal voor 25 g eiwit onnodig als hij al op 140+ g eiwit zit. Zeg dat vriendelijk en zonder moraal.

## Common Pitfalls
1. Using generic Herbalife values without checking flavour or serving details.
2. Confusing per 100 g with per serving.
3. Pretending a blurry package photo is exact.
4. Ignoring drinks, sauces, and preparation fats.
5. Forgetting to update the running day total.

## Verification Checklist
- [ ] Exact product or meal identified as far as possible
- [ ] Best available nutrition source used
- [ ] Exact vs estimate clearly stated
- [ ] kcal, protein, carbs, fat included
- [ ] Running daily total updated
- [ ] Advice kept practical and short
- [ ] Output matches de gebruiker's compact food-log format
