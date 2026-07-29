%{
  title: "Our hand-built tank lost every fight. Evolution won almost all of them.",
  date: ~D[2026-07-30],
  description: "A new front opens with a boring-sounding job: prove the creatures are any good before asking the interesting question. Evolution cleared a bar we had written down in advance, by a mile, using senses our own hand-built tank could not use at all. Then three claims we made about the result did not survive the week, and the tanks themselves refuted the story we had told about them.",
  tags: ["programme-7", "coevolution", "open-science"],
  sources: [66],
  corpus_ref: "faber insight 066 + PLAN_ROBO_RUMBLE"
}
---

The [last note](/research/notes/too-loose-or-too-tight) closed a research programme with a shelf of no's: ten experiments looking for an arms race between evolving creatures, and no arms race anywhere. It also named the thing that spoiled every one of those no's. Our creatures were evolved on modest budgets, and in several runs they demonstrably had not finished learning. So every "it never learned to do X" carried a quiet "at this budget" behind it, and a world that looks calm because nobody in it is any good looks exactly like a world that is calm for an interesting reason.

Fixing that is the whole job of this note. It is not a glamorous job. It is the one that has to happen first.

## The new world

Two tanks in a box. Each one is steered by a small artificial brain: it can drive, spin its gun independently of its body, sweep a radar, and shoot. It only sees what its radar happens to sweep, so most of the time it is working from an out-of-date guess about where the enemy is.

We chose this because the interesting question needs it. The question is whether rivalry can produce **loops**: tank A beats B, B beats C, C beats A, with no single best answer for evolution to settle on. A world with loops in it can keep surprising you forever. A world without them has a summit, and everything climbs it and stops.

Our previous world was a bare chase on a grid, and it turned out to have no loops in it at all. That is a good reason to change worlds.

## The bar, written down first

Before running anything we wrote down what would count as passing, and committed to it. This matters more than it sounds. A bar you set after seeing the results is not a bar, and the temptation to nudge it is strongest exactly when the result is close.

The bar was: **beat our best hand-written opponent about fifty-seven times in a hundred.** That opponent is a scripted tank that aims by predicting where you will be, assuming you keep moving the way you currently are, and adjusts its shot power for range.

Evolution came back at **about ninety-seven in a hundred.** Not a squeak past the line. A rout. For scale, an untrained tank with random wiring wins roughly one fight in eighty.

Two things came with that, and both are more interesting than the headline.

## The simplest possible brain also passed, and that is a warning

We ran a second arm with the hidden layer removed entirely: a direct wire from each sense to each control, with nothing in between. We expected it to fail, and we had said so in advance.

It won about ninety-four in a hundred.

The honest reading is not "this task is easy". It is that **we did the hard part for it**. We designed the seventeen senses the tank receives, and we designed them carefully: the enemy's position arrives pre-rotated into three different frames of reference at once, and two of the channels hand over the geometry of the enemy's motion already worked out. Our own written rationale for building it that way says a fixed network cannot form products of its inputs, so we would form them for it.

The consequence is that aiming, circling and radar tracking each collapse to a single weight. So the clever bit is real, and it is in the wiring we handed over, not in the brain that learned. Saying "a straight-line map is enough for this task" would be taking credit for the encoder's work.

## Then our own tank scored zero

As a sanity check we also built a tank by hand, setting the weights ourselves to what we thought the right behaviour was. The plan was that this would prove the task was possible at all before we spent any search on it.

**It lost every single fight.** Not a low score, zero.

And here is the part that nearly went badly. The original plan said: if the hand-built tank fails, stop the whole front and conclude that the senses must be broken. We had removed that rule shortly before running, for a reason of principle rather than convenience: a hostile reviewer had already pointed out that making the outcome depend on how good *we* are at hand-building tanks is exactly the dependency we had removed from the pass mark, and moving it from the mark to the gate does not remove it.

Good thing. Evolution then won almost every fight using the same senses our own tank could not use at all. Had we left the rule in, we would have stopped, written down "the senses are broken", and been confidently and permanently wrong about a working design.

We also disclose the awkward half: by the time we removed the rule, a pilot run had already shown early evolution doing better than zero. So the decision was made with a thumb on the scale, and the amendment records both reasons rather than just the flattering one.

## Two species came out, not one

The twenty runs did not produce twenty versions of the same tank. They split.

Thirteen landed in a **kill mode**, winning almost everything. Six landed near a coin flip. One sat alone in between. The gap between the two groups is wide and empty, so this is two outcomes rather than one outcome with a tail.

They are genuinely different policies, not better and worse versions of one. The near-parity six **drive straight into the enemy** and spend most of the match in physical contact, where the engine stops both tanks and bleeds energy from each and credits it to nobody. The kill-mode thirteen never do this even once. They pick a distance and stay there.

## The loops: what we claimed, and why it was wrong three times over

With the bar cleared we ran a quick extra check, unregistered and out of curiosity: take the twenty tanks and play every one against every other, looking for rock-paper-scissors loops.

We found loops, and said so. That claim was wrong in three independent ways, and finding out how is the most useful thing in this note.

**Too few fights per pairing.** The first pass ran each pairing over six starting positions. At that size one flipped match moves a result by a sixth, which jumps clean over the threshold we were using to decide whether a pairing counted as decided. So the loops were being manufactured by the coarseness of the measurement. Worse, the "robustness check" where we tried three different thresholds was hollow: at that size, two of the three thresholds were literally the same test, because no achievable result lay between them.

**The wrong thing counted.** The counter we used counts ordered arrangements, and a single loop of three tanks gets counted once or twice depending on which way round it runs. So the number we quoted was somewhere between one and two times the number of actual loops, and we did not say so.

**All three yardsticks were wrong.** This is the one that mattered. A loop count means nothing on its own; it only means something against how many loops pure chance would give. We quoted three different chance figures over the week, and every one of them was wrong for a different reason. One was a single random draw where an exact answer was available. One was measured on a different number of tanks, so the scales differed by a factor of nine. And the one we had built specifically to be comparable had an arithmetic fault that doubled its own margins, which meant it was answering a question one notch away from the one we were asking. Correcting that fault **flips the sign of the comparison.**

Read against three different yardsticks, the same twenty tanks gave "about a fifth of the chance rate", "far below anything chance produces", and "far above anything chance produces". The count was never the problem.

## Redone properly

Eighty starting positions instead of six. Every pairing played from both seats so no side gets an advantage. Thirty thousand matches. And a yardstick built to answer the actual question: keep every pairing exactly as decisive as we measured it, and shuffle only **who won**. That asks the one thing worth asking. Given results this clear-cut, is the ordering more loopy than a random ordering would be?

<figure class="nb-fig">
  <svg viewBox="0 0 600 240" role="img" aria-label="A number line of loop counts from zero to two hundred and fifty. A wide amber band sits between one hundred and fifteen and one hundred and seventy-two, marked as the range that pure chance produces, with its middle at one hundred and fifty-one. A single rust-coloured marker sits far to the left at eighteen, marked as what was actually found. The observed value is well below the entire chance range.">
    <text x="300" y="22" text-anchor="middle" font-family="ui-monospace, monospace" font-size="11" fill="currentColor" opacity="0.55">rock-paper-scissors loops among the twenty tanks</text>
    <rect x="290" y="70" width="114" height="46" rx="5" fill="#F2B142" opacity="0.35"/>
    <line x1="362" y1="66" x2="362" y2="120" stroke="#F2B142" stroke-width="2.5"/>
    <text x="347" y="58" text-anchor="middle" font-family="ui-monospace, monospace" font-size="10.5" fill="#F2B142" font-weight="bold">what pure chance gives</text>
    <text x="347" y="135" text-anchor="middle" font-family="ui-monospace, monospace" font-size="10" fill="currentColor" opacity="0.6">115 to 172, middle 151</text>
    <rect x="93" y="70" width="6" height="46" rx="2" fill="#C7583F"/>
    <text x="96" y="58" text-anchor="middle" font-family="ui-monospace, monospace" font-size="10.5" fill="#C7583F" font-weight="bold">we found 18</text>
    <line x1="60" y1="150" x2="560" y2="150" stroke="currentColor" stroke-opacity="0.3"/>
    <g font-family="ui-monospace, monospace" font-size="9.5" fill="currentColor" opacity="0.5">
      <line x1="60" y1="150" x2="60" y2="156" stroke="currentColor" stroke-opacity="0.3"/>
      <text x="60" y="170" text-anchor="middle">0</text>
      <line x1="160" y1="150" x2="160" y2="156" stroke="currentColor" stroke-opacity="0.3"/>
      <text x="160" y="170" text-anchor="middle">50</text>
      <line x1="260" y1="150" x2="260" y2="156" stroke="currentColor" stroke-opacity="0.3"/>
      <text x="260" y="170" text-anchor="middle">100</text>
      <line x1="360" y1="150" x2="360" y2="156" stroke="currentColor" stroke-opacity="0.3"/>
      <text x="360" y="170" text-anchor="middle">150</text>
      <line x1="460" y1="150" x2="460" y2="156" stroke="currentColor" stroke-opacity="0.3"/>
      <text x="460" y="170" text-anchor="middle">200</text>
      <line x1="560" y1="150" x2="560" y2="156" stroke="currentColor" stroke-opacity="0.3"/>
      <text x="560" y="170" text-anchor="middle">250</text>
    </g>
    <text x="300" y="205" text-anchor="middle" font-family="ui-monospace, monospace" font-size="10.5" fill="currentColor" opacity="0.6">of the 604 trios whose three results were all clear-cut, 18 formed a loop.</text>
    <text x="300" y="221" text-anchor="middle" font-family="ui-monospace, monospace" font-size="10.5" fill="currentColor" opacity="0.6">a random ordering would give about a quarter of them.</text>
  </svg>
  <figcaption>The correction, drawn against the only yardstick matched to how the fights actually came out. We had reported loops. There are far fewer than chance alone would produce.</figcaption>
</figure>

The answer inverts our claim. The tanks are **more orderly than chance, not less.** Of the trios whose three results were all clear-cut, three in a hundred formed a loop, where a random ordering gives twenty-five in a hundred. The observed count is below the lowest of two hundred random shuffles. These twenty tanks are very nearly ranked on a single ladder of competence.

**A small residue of real loops does survive.** At the strictest threshold there are twelve, and those are not measurement artifacts: every result in them is separated by at least twelve flipped matches, so no amount of coarseness explains them away. Loops exist in this world. There are just far fewer than an accident would produce, and far fewer than we said.

One more thing that yardstick showed, which we would not have guessed. The ladder the tanks impose on **each other** has almost nothing to do with how well they beat our scripted opponent. The two orderings are essentially unrelated. So "pick the best performers against the benchmark" is not a neutral way to choose which tanks go forward, and we now have to make that choice deliberately and write it down.

## The tanks refuted us too

We thought we knew how the winners win. Our scripted opponent aims by assuming you keep moving as you are, so the obvious counter is to weave, and make it miss. Both we and our sceptical reviewer expected that.

They do not weave. We checked two ways.

We measured how often each tank reverses its sideways direction, and compared it to how long an enemy bullet spends in the air. Over a whole bullet flight, a winning tank completes about a tenth of one reversal. That is an order of magnitude short of what dodging would require. For comparison, tanks from a differently trained arm run ten to twenty times as many reversals.

Then we replayed every enemy bullet against a **ghost** copy of the tank, frozen at the velocity it had the instant the enemy fired. If the tank were dodging the prediction, the ghost should be hit far more often. The ghost is hit at essentially the same rate. And four in five of the enemy's misses also miss the ghost, meaning those shots were already off target when they left the barrel.

What actually happens is duller and better. Every winning tank **picks a distance and locks itself there**, holding one narrow band for a third to two thirds of the entire match. And every one of them picks a distance beyond the point where our scripted opponent's own rule drops its gun to lower power and roughly halves its damage per hit. So for the whole match the enemy is shooting weakly while the tank shoots at full strength, and the tank hits more often besides. It is not a dodging contest. It is a damage exchange at a range the tank chooses.

There is a lovely check on this. A **spinner** we wrote as a low rung on the practice ladder, which just rotates in place and has no gun at all, holds our scripted opponent to a lower hit rate than most evolved champions manage. Being hard to hit is not what clearing this bar demonstrates.

## What we do not get to say

- **Not that the tanks are good in general.** Every number reads against one scripted opponent. Nothing here says how they do against each other, or against anything we have not written.
- **Not that hand-building this is hard.** Our hand-built tank scored zero on exactly one attempt, with no second try and no record of iteration. That is a fact about one attempt, not a measurement.
- **Not that the tanks learned to track or predict.** They cannot see bullets, and their senses report where the enemy is estimated to be **now**, not where it will be. Any story about prediction is unavailable to this front by design.
- **Not that any of the loop counting is a result.** It was unregistered, its thresholds and yardsticks were all chosen after seeing the answer, and it lives outside the signed record as an explicitly unsigned note with its faults attached. It supports one sentence: loops exist here. Nothing more.
- **Not that the world is fair.** The tanks all trained against a set of fixed opponents starting from fixed positions, in a world with no randomness at all. Nothing here tests what happens when the opponent does something new.

## What this buys

The bar is cleared with room to spare, honestly, and with the mechanism understood. That means the interesting question is now askable, and an absence of loops from here would say something about **the world** rather than about whether our search ran long enough. That ambiguity is exactly what spoiled the last programme, and it is now closed for this one rather than waved away.

The next step needs a design, not a run, and the reason is sharp. The space is almost entirely a single ladder with a few genuine loops in it. So rivalry could do two very different things here: it could **find and exploit** those loops, or it could just climb the ladder while the loops sit there unvisited. Those two produce nearly identical-looking histories and completely different conclusions. Telling them apart is the experiment, and it gets attacked by our hostile reviewer before a line of it is written.

The cheapest useful check comes first, though, and it is one the loop probe itself demands. Our twenty tanks are two species, not one, and **a mixed field can manufacture loops right at the boundary between them**, which would be a fact about how our training went rather than about the world. So the count gets redone within the kill-mode thirteen alone. If it collapses to nothing, what we found was a boundary effect.

## The record

Three of the claims in this note are corrections of claims we made earlier the same week, and they are written into the signed record beside the result rather than quietly dropped. One of them was caught by a hostile reviewer refusing to let the draft be signed. Another was caught by a mechanical check that went looking for numbers no saved file could back up, and found four. The third was caught by the tanks.

The rigorous version, including everything above that we are not entitled to claim, is the [signed insight](https://github.com/rgfaber/faber-ecosystem/blob/master/insights/066-evolution-clears-the-robo-rumble-competence-floor.md), and the loop probe with its ten listed faults is the [unsigned note](https://github.com/rgfaber/faber-ecosystem/blob/master/insights/066-note-crossplay-intransitivity-UNSIGNED.md) beside it. The plan the front runs to is [here](https://github.com/rgfaber/faber-ecosystem/blob/master/plans/PLAN_ROBO_RUMBLE.md). As always, [we publish the ones where we were wrong](/research/notes/why-we-publish-our-failures), which is easy to promise and less comfortable to do.
