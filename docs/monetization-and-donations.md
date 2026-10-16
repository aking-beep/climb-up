# Monetization and community donations: the decision, and when to make it

**Status: deliberately not built.** The beta build has no purchases, no
ads, no donation links and no payment code. This page fixes three things
now:
- what will never be done;
- the options to choose from;
- the retention numbers that unlock the choice.

The aim is that the choice is made from evidence after the beta, not
guessed before it.

## When to decide

After the 30–50 person beta (`docs/playtest-plan.md`), run
`tools/playtest/retention.py`. Then:

| Result | Decision |
| --- | --- |
| D1 ≥ 35%, D7 ≥ 10%, tutorial completion ≥ 85%, no crashes or lost saves | Pick one primary model below, build it behind a setting, and test it in the next closed round |
| D1 or D7 under the benchmark | No monetization work. Fix onboarding and the replay loop, then run another beta round |
| Strong Crag replay but weak expedition completion, or the reverse | Monetize the stronger mode only, and keep the other free |

With 30–50 testers the numbers are directional. Any model is tried with
a closed round before it is turned on for everyone.

## Never (whatever the numbers)

- **No pay-to-win.**
  - Nothing bought changes climbing speed, stamina, grip, falls, scores
    or styles.
  - Boards and first ascents stay earned. Shoes stay unlocked by play.
- **No loot boxes or random paid rewards.**
- **No energy timers or paid continues.**
  - A careful retreat is the design working. A paywall on retrying
    would punish it.
- **The daily route and its board stay free.**
- **No behavioural ads and no third-party ad SDK.**
  - Under-13 accounts already get no public name and no global boards.
    No ads may reach them either.
  - Any ad would need a new Data safety answer (`docs/release/data-safety.md`).
- **The educational content stays free.** That covers judgment notes,
  the lessons, and the altitude and safety content.

## Options

| Model | What the player gets | Fits CLIMB UP because | Costs and risks |
| --- | --- | --- | --- |
| **A. Premium unlock** (one purchase) | Crag and the first Expedition route free. One purchase opens the other routes and future crags | Simple, honest, and matches "earned, not bought" | Lower conversion. Needs Play Billing (and StoreKit later) |
| **B. Content packs** | New crags and new mountains as one-off purchases | Content is what players finish. Each pack stands alone | A steady content pipeline. Splits the boards per pack |
| **C. Cosmetics** | Chalk colours, rope colours, clothing, camp decorations | No effect on play. Shows on shared result cards | Art cost. Earns little at small scale |
| **D. Supporter pack plus community donation** | A cosmetic "supporter" badge and a thank-you scene. ARC Labs gives a stated share of each sale to a porter-welfare or mountain-safety charity | Matches the expedition's theme: the porters and teammates who get you up and down | Needs an agreement with the charity, plus legal review (commercial co-venture rules in some places). See below |

**Recommended first try if the gate passes: A, with D as an optional
add-on.** A keeps the game whole and free to try. D gives players a way to
support the cause without making the game a fundraiser.

## The community donation flow (option D), when chosen

The stores restrict money taken for charity inside an app. Policies
change, so check the current Google Play Payments policy and App Store
Review Guideline 3.2 before building. The safe shape:

1. **The in-app purchase is ARC Labs' own product**, through Google Play
   Billing (StoreKit on iOS). For example: "Supporter pack: £2.99". It
   isn't a donation, so the store's normal rules apply.
2. **ARC Labs donates a stated share of supporter-pack revenue** to the
   chosen charity from its own accounts. The store page and the in-game
   screen say exactly what share, and to whom.
3. **A published yearly total:** what was given, with the charity's
   receipt.
4. **Optional:** a plain link out to the charity's own donation page.
   It's shown only to players 13 and over, opens in the browser, and has
   no reward in the game. Check it against both stores' rules first.
5. **Never:**
   - collect donations for a third party through the app's own payment
     flow;
   - promise a tax deduction;
   - show the flow to under-13 accounts.

Before building:
- choose the charity, and sign a short agreement on the share and the use
  of its name;
- have a lawyer check the wording for the countries in the store listing;
- add the charity to `store/` listing text and to the privacy policy if
  any data is shared (none should be).

## What building it would touch

Nothing until the gate passes. When it does:
- **Play Billing:** the Godot Google Play Billing plugin and an
  entitlement store in `SaveGame`. Purchases are restored from the store,
  never trusted from the save alone.
- **A store screen** under `godot/modes/`.
- **Tests:**
  - an entitlement unlocks content;
  - a refunded purchase removes it;
  - nothing bought changes play: the scoring tests run with every
    entitlement on.
- **Docs:**
  - Data safety: purchase history is collected by Google, not by us;
  - the privacy policy;
  - the Play listing's "contains in-app purchases".
