%{
  title: "Two networks learn to chase each other (and why we would not call it an arms race)",
  date: ~D[2026-07-23],
  description: "We put a predator and a prey, each a tiny neural network, on a grid and let them evolve against each other. They got better. They did not run in circles. The hunter clearly pulled ahead. Then two rounds of adversarial review and a decisive control experiment made us delete our own headline: there is no arms race here, just two learners on two treadmills.",
  corpus: :faber,
  tags: ["programme-7", "coevolution", "open-science"],
  sources: [57],
  corpus_ref: "faber insight 057 + CHARTER_P7_COEVOLUTION"
}
---

The last two notes built the equipment. ["Running to stay in place"](/research/notes/running-to-stay-in-place) showed why the head-to-head scoreboard lies when both sides improve. ["A ruler you can trust"](/research/notes/a-ruler-you-can-trust) built a fixed yardstick and stress-tested it three ways. Now we spend that equipment on a question we actually did not know the answer to.

## The game

A small grid that wraps around at the edges, like the old arcade screens where flying off the right side brings you back on the left. On it, two players: a **pursuer** and an **evader**. Each one is a tiny neural network, a few dozen numbers, that looks at where its opponent is and decides which way to step. The pursuer wins by landing next to the evader. The evader wins by staying away.

We evolve two whole populations at once, each generation, each side selected for how well it does against the current crop of opponents. This is real coevolution on a real embodied task, not a numbers game. Every move is a live decision by an evolved network.

## First, we had to pick a fair speed

If the pursuer is much faster, it always wins and there is nothing to study. If the evader is faster, it always escapes. The only place a genuine two-sided contest can live is the **knife-edge** where a competent hunter catches a competent runner about half the time.

Finding that edge turned out to matter more than we expected. The catch rate does not slide smoothly with speed; it jumps in steps. There is no exact "50-50" speed on our grid, only a rung just below it (the runner slightly favoured) and a rung just above (the hunter slightly favoured). So instead of picking one and pretending, we ran the **whole experiment twice**, once on each rung. If the story flips between the two, then the story was never about the biology; it was about which rung we cherry-picked.

## What happened

Three things, and we have to be careful about which we get to keep.

**They improve, and they do not run in circles.** Using the cross-time tournament from the last note (every past champion against every other), we found zero loops. Later champions beat earlier ones, cleanly, on both rungs. So this game **climbs**, it does not rotate. That is a real, solid result: no cycling.

**The hunter clearly pulls ahead.** Measured against the frozen yardstick, the pursuer's skill ends well above where it started, on both speed rungs. Robust.

**The runner barely holds on.** This is where it gets honest. On the runner-favoured rung, the evader's skill ends measurably above its start. On the hunter-favoured rung, it climbs to a peak and then slides back down to almost exactly where it began, its gains eaten as it over-specialises against the current hunter and forgets how to handle anyone else. Tempting headline: "the outcome flips depending on the balance." But when we actually measured whether those two rungs **differ**, the difference did not clear the bar. Two readings that straddle a line are not the same as a proven difference between them. So we do not get to say "it depends on the balance." We get to say the runner is **marginal**, right at the edge of what we can detect.

## The part where we deleted our own headline

Our first write-up said: "a sustained two-sided arms race, fragile to the exact balance, replicating a famous 1998 result." It sounded great. It was wrong three times over, and an adversarial reviewer (a deliberately skeptical AI we run against every result before signing it) caught all three.

- **"Arms race" was not earned.** Both sides improving against a fixed yardstick shows two-sided **progress**. It does **not** prove they are driving **each other**. Two runners on two separate treadmills also both improve. To earn the words "arms race" you have to show the coevolving pair beats a control where each side trains alone. We have not run that control yet, so the words come out.
- **"Fragile / depends on the balance" was not earned.** As above: the two rungs did not provably differ. Two points that straddle a threshold are not a trend.
- **The famous-result comparison was backwards.** The 1998 work is remembered for finding cycling, strategies chasing each other in circles. We found the **opposite**: no cycling at all. Citing it as a match was exactly wrong.

What survived, after the cuts: real neural pursuit-evasion **climbs monotonically with no cycling; the hunter reliably improves; the runner is marginal; and whether it is a true mutual arms race is still open.** Less thrilling than the first draft. Much more likely to be true.

## Why we tell it this way

It would have been easy to publish the exciting version. The equipment we spent three notes building exists precisely so we do not. A trustworthy ruler is worth most exactly when it tells you the boring answer, because that is when the temptation to round up is strongest.

## The control, and its answer

So we ran the control that could earn (or refuse) the word "arms race". Give each side a **frozen** opponent, one that never adapts, and let it improve against that fixed target. Then compare: does the pair whose opponent **moves** end up better on the yardstick than the pair whose opponent **stands still**? If a moving target drives extra progress, that is the arms race. If not, they were on separate treadmills.

The answer came back clean, and it was the modest one. On every side, at both speed rungs, the coevolving player ended up **no better** than the one that trained against a frozen opponent. A moving target bought nothing you could measure. So the improvement we saw is real, but it is each side climbing against whatever opponent it is handed, not two rivals spiralling each other upward. On this small grid, at this scale, there is **no arms race** to find, only two learners on two treadmills.

That closes the loop honestly. What survives, signed: real neural pursuit-evasion improves and does not run in circles; the hunter reliably gets better; the runner barely holds on; and the exciting story, two minds driving each other to ever-greater cunning, is not there. To find that, we suspect you need a richer world than a bare grid: space, food, many agents, somewhere for an escalation to actually go. That is where the next programmes point.
