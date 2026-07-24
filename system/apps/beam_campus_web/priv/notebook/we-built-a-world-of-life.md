%{
  title: "We built a tiny world of life to find an arms race (it refused, and told us why)",
  date: ~D[2026-07-24],
  description: "On a bare grid, two evolving networks would not arms-race. So we built them a living world: food, hunger, death, and many creatures at once. Across five experiments the world refused just as firmly, and each refusal was a lesson. Here is the honest map of why a simple artificial world does not spontaneously catch fire.",
  tags: ["programme-7", "artificial-life", "coevolution", "open-science"],
  sources: [58, 59, 60, 61, 62],
  corpus_ref: "faber insights 058-062 + PLAN_FLATLAND"
}
---

In the last note (["Two networks learn to chase each other"](/research/notes/two-nets-learn-to-chase)) a predator and a prey, each a tiny neural network, evolved against each other on a bare grid and would not produce an **arms race**: no runaway escalation where each side keeps forcing the other to get better. Two learners on two treadmills, not a spiral.

The bare grid was thin. It had no food, no hunger, no death, one hunter and one runner and nothing else. Maybe an arms race needs a richer world with somewhere for escalation to go. So we built one: a small **artificial-life world**, in the tradition of the ALife simulations Gene Sher's Erlang work explores. Plants grow. Creatures spend energy to move, eat to refill it, and die when they run out. This note is the honest story of five experiments in that world. It refused to arms-race just as firmly as the grid did, and every refusal taught us something specific.

## First: does the world even work? (058)

Before asking hard questions you check the ruler. We confirmed the world behaves: a hand-coded forager thrives and a random wanderer starves; a small network can **learn to forage** and, separately, **learn to hunt**. We also built a "mind-reader" that measures three separate skills without confusing them: how good a creature is at foraging, at fleeing, and at hunting. And we re-checked our earlier "no arms race" result inside the new world with the plants switched off: same answer. Good. The instrument is trustworthy. Now the real questions.

## The prey that never learned to flee (059)

We gave the prey a living: forage to not starve, flee to not be eaten. Two things happened, and the second surprised us.

Predators clearly **hurt** foraging: a prey with a hunter around ate far less than one left in peace. But when we measured the prey's actual **fleeing skill** on our ruler, it had barely moved from the level of a network that had never seen a predator at all. The prey did not get better at running away. It just foraged less. There was no "trade foraging for fleeing" balance to find, because the fleeing skill was never learned in the first place. The energy of survival did not teach escape.

## It did learn to dodge (060), but we could not connect the dots

Maybe the prey was doing something the fleeing-ruler could not see. So we ran a cleaner test: freeze a prey, place a predator at a chosen distance, and watch its single next step. The pressured prey **did** step away from a nearby predator more often than chance, and more than a control that saw predators but had no reason to avoid them. So it had learned a real anti-predator move: near-predator **repulsion**.

But here we had to stop ourselves. We could measure that the prey dodges, and separately that predators reduce its foraging. We could **not** show the dodging *causes* the foraging loss. Two true facts, no proven line between them. An adversarial reviewer (a deliberately skeptical AI we run every result past) made us delete the sentence that linked them. The honest version: the prey learned to dodge; whether that dodging explains the foraging collapse is untested.

## Put many of them in one world, and it collapses (061)

The really new ingredient was still missing: **many** creatures living, breeding, and dying in **one shared world** at once, no outside referee. This is the ingredient real ecosystems have and our earlier one-on-one contests lacked. Maybe *this* is where an arms race lives.

It is not, because the world **crashes**. With ordinary greedy hunters the population boom-busts to total extinction, fast: predators eat all the prey, then starve. We tried hard to save it. We added the textbook stabilizers ecologists use: predators that pause to digest, predators that are a little slower than prey, predators that only see nearby food so distant prey are safe. We swept the knobs across a whole grid of settings, on the large map and the small one. Nothing coexisted. The predator-prey world, with these simple rules, has no stable balance to sit in. That is itself a finding: a shared living world does not automatically settle into a lasting ecosystem.

## So let evolution fix it? There is no time (062)

Here was the tempting idea: real ecosystems avoid collapse partly because over-greedy predators evolve **restraint** (they do not eat their whole food supply). So let the predators evolve and maybe they discover prudence and the world stabilizes.

The reviewer caught the fatal flaw before we wasted a big build: the world dies in about **one predator generation**. Evolution needs *many* generations of selection to change anything. If everyone is dead in one generation, there is no time for evolution to happen at all. "Evolution can't fix it" would be true for a boring reason (no time), not an interesting one.

So we asked the honest prior question: is there *any* setting where the world lasts long enough for evolution to even get going? We found a **squeeze**. The only way a predator can show restraint in this world is to *not hunt*, which means *not eat*, which means *starve*. So greedy predators kill their food and collapse, and restrained predators starve and collapse. There is no free restraint: prudence and starvation are the same move. Across every setting we tried, coexistence died within about one generation. No room for evolution to work.

## What five refusals add up to

Put the whole run together: no arms race on the grid, no learned fleeing, a dodge we could not connect, a shared world that collapses, and no time for evolution to rescue it. From five different directions the same answer: **this simple artificial world does not spontaneously produce a lasting, escalating, living dynamic.** Not because we forgot one magic ingredient, but because the dynamics fall apart or refuse to couple wherever we push.

That is not a failure, it is a **map**. It tells us precisely what a world would need to do better: be large and spatially structured enough that prey have real refuges and populations can persist for many generations, or offer a form of restraint that does not equal starvation. That is a genuine design problem, and it is the honest next step, rather than another tweak to a world we have now thoroughly understood.

We are publishing all five results, signed and dated, including the three where the interesting answer was "no" and the two where a reviewer made us walk back our own words. A map of where the fire *isn't* is worth as much as a spark, and a lot more honest.
