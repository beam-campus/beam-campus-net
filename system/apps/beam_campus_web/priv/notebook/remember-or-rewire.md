%{
  title: "Does a machine learn better by remembering, or by rewiring itself?",
  date: ~D[2026-07-22],
  description: "Two ways for a tiny neural network to hold onto what it knows, and a run of experiments (including the ones where we turned out to be wrong) working out when each one wins.",
  tags: ["programme-3", "memory", "plasticity"],
  sources: [31, 34, 35, 38, 39, 40, 41, 43, 45, 46],
  corpus_ref: "faber insight 046 + SYNTHESIS_P3"
}
---

Someone reads you a phone number and asks you to walk to the other end of the house and dial it. You have two ways not to lose it on the way:

- **Hold it in your head** and repeat it the whole walk, or
- **Write it on your hand** and glance down when you get there.

A neural network faces exactly this choice, and it turns out the choice matters more than you'd think. This is the story of a small pile of experiments trying to answer one question: when a network has to hold onto something, is it better to **keep it in its activity** (like repeating the number), or to **write it into its own wiring** (like the note on your hand)?

We call the first one *memory by storage* and the second *memory by learning*. Both are real things brains and artificial networks do. We wanted to know which is better, and why.

## The little maze

Our test is a tiny T-maze. A signal flashes at the start ("go left" or "go right"), then the network walks down a blank corridor, and at the junction it has to turn the way it was told. The catch: the signal is only shown at the very start. To get it right, the network must *carry* it across the corridor. That carrying is the memory we're measuring.

On the easy version, both approaches ace it. So we started making life hard.

## What happens under stress

Make the corridor **longer**, and both still cope, but the storage approach gets noticeably more expensive to evolve. Add **noise** to the network's senses, though, and the two come apart sharply: the stored signal gets swamped, while the written-in-the-wiring version holds. Here is the reason, which we were able to measure directly:

<figure class="nb-fig">
  <svg viewBox="0 0 520 170" role="img" aria-label="A stored signal decays across the corridor toward zero; a written-in imprint stays strong.">
    <text x="10" y="24" font-family="ui-monospace, monospace" font-size="12" fill="#4E9F6B">imprint (written into the wiring)</text>
    <rect x="10" y="32" width="500" height="16" rx="8" fill="#4E9F6B" opacity="0.22"/>
    <rect x="10" y="32" width="500" height="16" rx="8" fill="#4E9F6B"/>
    <text x="10" y="92" font-family="ui-monospace, monospace" font-size="12" fill="#C7583F">state (held in the activity)</text>
    <rect x="10" y="100" width="500" height="16" rx="8" fill="#C7583F" opacity="0.18"/>
    <rect x="10" y="100" width="500" height="16" rx="8" fill="#C7583F">
      <animate attributeName="width" values="500;24;500" keyTimes="0;0.8;1" dur="5s" repeatCount="indefinite"/>
    </rect>
    <text x="10" y="150" font-family="ui-monospace, monospace" font-size="11" fill="currentColor" opacity="0.6">start of corridor</text>
    <text x="510" y="150" text-anchor="end" font-family="ui-monospace, monospace" font-size="11" fill="currentColor" opacity="0.6">the junction</text>
  </svg>
  <figcaption>The held signal leaks away across the corridor (about 25x weaker by the junction), so a bit of noise is enough to lose it. The imprint written into the weights just stays put.</figcaption>
</figure>

So under stress, *writing it down beats holding it in your head.* And the very best version writes a **separate little rule for every single connection**, which lets a network survive both a long corridor *and* noise where nothing else can.

## The part where we were wrong (twice)

Here is the thing we care about most, and the reason we publish a lab notebook at all: we got two tempting explanations wrong, and we'd rather show you than quietly bury them.

- We first concluded that storage was **hopeless at holding two things at once**. It wasn't. That was a **testing mistake** on our part (we weren't resetting it fairly). Fixed, it kept up fine. [Insight 038.]
- We then had a lovely theory that per-connection wiring wins because it keeps the two memories from **interfering**. We measured it. The opposite was true. The theory was dead. [Insight 040.]

What actually held up was subtler and, honestly, more interesting: the per-connection version wins because evolution can *find* the robust solution more readily. It is about **searchability**, not a tidy static property. [Insight 041.]

## The twist: holding is not learning

Then we changed the question. Instead of *hold this thing you were shown*, we asked the network to *figure out something nobody told it, from reward alone, and re-figure it when the world changes* (which button gives the treat, then we swap the buttons). That is closer to real learning.

And here the clean story dissolved. Storage, simple rewiring, fancy rewiring: **all of them do about equally well.** We tried three different ways to break the tie and couldn't. The reason is quiet and satisfying: this kind of learning works by *averaging reward over many tries*, and averaging is a noise filter, so the very thing that separated the mechanisms for memory gets smoothed away for learning. [Insights 043 to 045.]

So the headline "rewiring beats remembering" is true, but only for **holding information under stress**, not for learning in general. That is a much more honest sentence than the one we started with.

## Where it lands: a machine that fixes itself

The payoff is a controller that keeps a pole balanced while a hidden fault flips its motor mid-run. A fixed controller topples. One with reward-gated rewiring *feels the pole falling and re-wires itself* to recover. That is post-deployment adaptation, and you can watch it, evolve your own, and try to break it:

<p class="nb-cta"><a href="/research/workbench">Open the workbench and try it &rarr;</a></p>

## Read the rigorous version

None of the above asks you to take our word for it. Every claim here is a signed, dated entry in the open corpus, with the raw numbers and the statistics, including the two we retracted. Follow the *sources* under this post, or start with the [Programme 3 synthesis](https://codeberg.org/rgfaber/faber-ecosystem/src/branch/master/plans/SYNTHESIS_P3.md).
