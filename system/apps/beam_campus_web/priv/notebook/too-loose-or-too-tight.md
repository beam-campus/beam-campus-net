%{
  title: "Too loose or too tight: the shape of ten experiments that never caught fire",
  date: ~D[2026-07-29],
  description: "We spent a research programme looking for an arms race between evolving creatures and never found one. Closing it out, the ten results turn out to have a shape: every world we built was either too loosely coupled for anything to escalate, or so tightly coupled that everything died first. There was no setting in between, and we never once tried moving the world itself.",
  tags: ["programme-7", "coevolution", "open-science"],
  sources: [53, 54, 55, 56, 57, 58, 59, 60, 61, 62],
  corpus_ref: "faber insights 053-062 + SYNTHESIS_P7"
}
---

This note closes a research programme. Four earlier notes told it in pieces: [why the head-to-head scoreboard lies](/research/notes/running-to-stay-in-place), [how we built a ruler we could trust](/research/notes/a-ruler-you-can-trust), [two networks learning to chase each other](/research/notes/two-nets-learn-to-chase), and [a small world of living things that kept collapsing](/research/notes/we-built-a-world-of-life). Ten signed results in all.

This one says what the whole thing amounts to. That includes the parts we do not get to claim, the confound we never cleared, and the question we never thought to ask until it was over.

The programme had one motivating idea. Evolution's most impressive results are supposed to come from **rivalry**: a predator gets sharper, so the prey gets faster, so the predator gets sharper again, round and round, with no ceiling. Nobody has to design the ceiling away because the opponent keeps raising it. That is an arms race, and it is the engine people point to when they explain how open-ended novelty could come from a simple rule.

We went looking for one. We did not find it. Ten experiments later, the interesting part is not the absence, it is the **shape** of the absence.

## First, the thing we actually keep

Before hunting a dynamic you have to be able to see it, and coevolution is unusually good at fooling the instruments. So half the programme was spent building the instruments and trying to break them, on toy problems where we already knew the right answer.

Four rules came out of that, and they are the programme's most durable product:

- **The obvious scoreboard lies.** Score each side against its current opponent and you get roughly 50-50 forever, even while both sides improve enormously, because the yardstick is climbing too. Use a **fixed** opponent set instead.
- **A fixed yardstick still goes blind if it is too easy.** One of ours saturated after 13% of a run and then reported "no further progress" while the thing it was measuring climbed another seven-eighths of its total. Fixed is not enough. It has to stay ahead of you.
- **What you select on can quietly diverge from what you want.** If true quality means being good at two things at once, and you reward the sum, you get away with it as long as both are equally easy to improve. The moment one gets expensive, the population pumps the cheap one and abandons the expensive one, which is exactly the thing that mattered. The scoreboard looks like progress the whole time.
- **A flat reading can mean two very different things.** Under a game where strategies chase each other in circles, our yardstick honestly reported "no progress", which was correct, but it could not tell us that circling was happening. Detecting that needs a different instrument entirely, every past champion played off against every other.

None of the later negatives dent any of this. If you take one thing from the programme, take the toolkit.

## The shape: too loose, or too tight

Here is what we did not see until we sat down to close the programme out.

We built worlds of increasing richness, adding one lifelike ingredient at a time: a bare chase on a grid, then food and hunger and death, then many creatures breeding and dying together in one shared place. Every one of them failed to produce an arms race. But they did not fail the same way. They failed at **opposite ends**.

<figure class="nb-fig">
  <svg viewBox="0 0 600 250" role="img" aria-label="A horizontal scale showing how strongly two evolving sides affect each other. At the left end, weak coupling, labelled nothing to escalate. At the right end, strong coupling, labelled everything dies in about one generation. The middle band, where an arms race would live, is empty and marked never reached.">
    <text x="300" y="22" text-anchor="middle" font-family="ui-monospace, monospace" font-size="11" fill="currentColor" opacity="0.55">how strongly the two sides actually affect each other</text>
    <rect x="40" y="60" width="170" height="70" rx="6" fill="#C7583F" opacity="0.85"/>
    <rect x="390" y="60" width="170" height="70" rx="6" fill="#C7583F" opacity="0.85"/>
    <rect x="215" y="60" width="170" height="70" rx="6" fill="none" stroke="#F2B142" stroke-width="2" stroke-dasharray="7 5"/>
    <g font-family="ui-monospace, monospace" font-size="12" font-weight="bold" fill="#ffffff">
      <text x="125" y="90" text-anchor="middle">TOO LOOSE</text>
      <text x="475" y="90" text-anchor="middle">TOO TIGHT</text>
    </g>
    <g font-family="ui-monospace, monospace" font-size="10" fill="#ffffff" opacity="0.9">
      <text x="125" y="110" text-anchor="middle">nothing to escalate</text>
      <text x="475" y="110" text-anchor="middle">everyone dead in ~1 generation</text>
    </g>
    <g font-family="ui-monospace, monospace" font-size="11" font-weight="bold" fill="#F2B142">
      <text x="300" y="90" text-anchor="middle">an arms race</text>
      <text x="300" y="108" text-anchor="middle">would live here</text>
    </g>
    <text x="300" y="152" text-anchor="middle" font-family="ui-monospace, monospace" font-size="10.5" fill="currentColor" opacity="0.6">never reached</text>
    <line x1="40" y1="180" x2="560" y2="180" stroke="currentColor" stroke-opacity="0.25"/>
    <text x="300" y="212" text-anchor="middle" font-family="ui-monospace, monospace" font-size="10.5" fill="currentColor" opacity="0.6">the one knob that loosens the right-hand end is "hunt less",</text>
    <text x="300" y="228" text-anchor="middle" font-family="ui-monospace, monospace" font-size="10.5" fill="currentColor" opacity="0.6">which is the same move as "starve"</text>
  </svg>
  <figcaption>The programme's shape, drawn after the fact. Both ends are failures, for opposite reasons, and no experiment landed in between.</figcaption>
</figure>

**The bare chase was too loose.** A hunter and a runner, each a small network, evolving against each other on a wrap-around grid. They improved. They did not go in circles. But when we ran the control that decides it, giving each side a **frozen** opponent that never adapts, the coevolving pair ended up no better on the yardstick than the pair training against something that stood still. The opponent was moving, and the movement bought nothing. There was contact but no leverage.

**The shared world was too tight.** Put many creatures in one place to live, breed and die with no referee, and the coupling is suddenly extremely real: the predators eat the prey to extinction and then starve, every single time, across every combination of settings we tried, including the ones ecological theory says should be the safe ones. The world dies in about 39 steps, which is roughly **one predator generation**. So there is coupling, and it is lethal before anything can adapt to it.

**And there is no knob between the two.** The obvious fix for the tight end is restraint: predators that ease off before they eat everything. Real ecosystems are thought to do something like this. But in our world the only way a predator can decline to hunt is to decline to eat, so restraint and starvation are literally the same action. Greedy predators kill their food supply and collapse; prudent ones starve and collapse faster. The dial we needed does not exist in this world, and discovering that it does not exist is the single most useful thing the programme found.

## The distinction that did all the damage: variety is not rivalry

If there is one idea worth carrying out of this, it is this one, and it took two rounds of adversarial review to see it clearly.

When you evolve against a coevolving opponent, you get two things at once. You get **rivalry**, the thing we were hunting: your opponent's improvement specifically pushes you to improve. And you get **variety**: because your opponent keeps changing, you never get to overfit to one narrow target.

Variety is genuinely valuable. Our coevolving hunter really did beat a hunter trained against a single strong frozen opponent, and that is a real effect, reproduced. It is very tempting to write that up as an arms race.

It is not one. Because a hunter trained against a **varied but non-adapting** opponent did just as well. Whatever the coevolving pair gained, it gained from facing a moving assortment, not from facing an adversary. Every time we thought we had rivalry, the control said variety.

That distinction is why the headline of an earlier note got deleted, and it is why we now think "the opponent improves too" is a much weaker ingredient than the literature's imagery suggests.

## What we do not get to say

The corpus is strict about this, so the public version should be too. None of the following is established by any of it:

- **Not that evolving neural networks cannot produce open-endedness.** One engine, one family of very small worlds, one style of search. That is a corner of the space, not the space.
- **Not that populations cannot coexist in general.** A large ecological literature says they can, given the right structure. Ours did not manage it. Those are different sentences.
- **Not that a bigger or richer world would work.** This is the one we most want to say and least get to. "You need a materially different world" is our best current **hypothesis for why it failed**, and we have not tested it. Believing it is fine. Publishing it as a result is not.
- **Not that the prey's dodging explains its foraging collapse.** We measured that pressured prey learn to step away from a nearby hunter, and separately that hunters reduce how much prey eat. We never connected them, and we deleted the sentence that did.

## The confound we never cleared

Honest limitation, stated plainly because it touches nearly every negative above: our creatures were evolved on modest budgets, and in several runs they demonstrably had not finished learning. A prey that "never learned to flee" might have learned to flee with ten times the search.

We know the networks are **capable** of the behaviours: we checked that separately, and in one case built the ideal forager by hand, directly in the network's own weights, to prove the shape was expressible. What we could not settle is whether the search found everything that was there. A whole separate programme went after exactly that question and produced no signable result at all.

So every "it never learned X" in this arc should be read with "at this budget" quietly attached.

## The question we never asked

This is the part that surprised us most, and we only noticed it while writing the closing document.

In all ten experiments, the world stood still and the creatures moved. We varied hunger, speed, population, spatial structure, restraint. We never once varied **the world itself**. Nothing in the programme ever put the environment under evolutionary pressure, or let it change in response to what the creatures were becoming.

That is not an oversight we can wave away, because it was written into the programme's own charter from the start as its second central question, and it was never run. It asks whether a setup where the challenges and the solvers evolve **together** keeps generating genuinely new solved problems, or whether it stalls. Every result above answers the first question. None of them touch the second.

Closing a programme does not answer a question you never asked. So we are closing it explicitly on the first question, with the second one written down, unrun, and honest about being unrun.

## Why publish a shelf of no's

Because a map of where the fire is not is worth about as much as a spark, and it is far more likely to be true. Because these are the results that quietly do not get written up, which is exactly why everybody keeps re-running them. And because we said we would publish [the ones where we were wrong](/research/notes/why-we-publish-our-failures), and it is easy to say that while the results are going well.

Every rung in this programme was attacked before it ran and attacked again before it was signed, by a deliberately hostile reviewer whose only job is to break our reasoning. Every single one came back redesigned or with required changes. Two results we were briefly excited about evaporated when we ran them again at larger scale. That is the process working, and it is the reason we are willing to put a ten-result no in public.

## The record

Every number here is a signed, dated entry in the open corpus, including the two claims we retracted and the readouts we had to throw away. Follow the *sources* under this post, or start with the [Programme 7 synthesis](https://github.com/rgfaber/faber-ecosystem/blob/master/plans/SYNTHESIS_P7.md), which is the rigorous version of this note, or the [signed insights index](https://github.com/rgfaber/faber-ecosystem/blob/master/insights/INDEX.md).
