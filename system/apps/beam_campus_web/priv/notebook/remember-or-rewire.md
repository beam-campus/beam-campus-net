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

Make the corridor **longer**, and both still cope, but the storage approach gets noticeably more expensive to evolve. Add **noise** to the network's senses, though, and the two come apart sharply: the stored signal gets swamped, while the written-in-the-wiring version holds.

<figure class="nb-fig">
  <svg viewBox="0 0 560 300" role="img" aria-label="Times each network solved the maze as sensor noise rises. The learning network stays at 8 out of 8 at every noise level; the storage network keeps up at first, then collapses to 0 out of 8 at high noise.">
    <g font-family="ui-monospace, monospace" font-size="11" fill="currentColor" opacity="0.55">
      <text x="74" y="58" text-anchor="end">8/8</text>
      <text x="74" y="150" text-anchor="end">4/8</text>
      <text x="74" y="244" text-anchor="end">0/8</text>
    </g>
    <text x="20" y="150" font-family="ui-monospace, monospace" font-size="10" fill="currentColor" opacity="0.5" transform="rotate(-90 20 150)" text-anchor="middle">times it solved the maze</text>
    <line x1="86" y1="240" x2="522" y2="240" stroke="currentColor" stroke-opacity="0.2"/>
    <g>
      <rect x="150" y="54" width="34" height="186" rx="6" fill="#4E9F6B"/>
      <rect x="190" y="54" width="34" height="186" rx="6" fill="#C7583F"/>
      <rect x="288" y="54" width="34" height="186" rx="6" fill="#4E9F6B"/>
      <rect x="328" y="54" width="34" height="186" rx="6" fill="#C7583F"/>
      <rect x="426" y="54" width="34" height="186" rx="6" fill="#4E9F6B"/>
      <rect x="466" y="236" width="34" height="4" rx="2" fill="#C7583F" opacity="0.55"/>
    </g>
    <g font-family="ui-monospace, monospace" font-size="10.5" fill="currentColor" text-anchor="middle">
      <text x="167" y="48" opacity="0.8">8/8</text>
      <text x="207" y="48" opacity="0.8">8/8</text>
      <text x="305" y="48" opacity="0.8">8/8</text>
      <text x="345" y="48" opacity="0.8">8/8</text>
      <text x="443" y="48" opacity="0.8">8/8</text>
      <text x="483" y="228" opacity="0.9" fill="#C7583F">0/8</text>
    </g>
    <g font-family="ui-monospace, monospace" font-size="11" fill="currentColor" opacity="0.7" text-anchor="middle">
      <text x="187" y="262">a little noise</text>
      <text x="325" y="262">more noise</text>
      <text x="463" y="262">a lot of noise</text>
    </g>
    <text x="325" y="278" text-anchor="middle" font-family="ui-monospace, monospace" font-size="9.5" fill="currentColor" opacity="0.5">(storage still solves here, but needs ~6x the tries)</text>
    <g font-family="ui-monospace, monospace" font-size="11">
      <rect x="176" y="288" width="12" height="12" rx="3" fill="#4E9F6B"/><text x="194" y="298" fill="currentColor" opacity="0.75">rewiring (learns)</text>
      <rect x="360" y="288" width="12" height="12" rx="3" fill="#C7583F"/><text x="378" y="298" fill="currentColor" opacity="0.75">activity (stores)</text>
    </g>
  </svg>
  <figcaption>Turn up the noise on the network's senses. The rewiring approach (green) still solves the maze every single time. The storage approach (terracotta) keeps up while the noise is mild, then at high noise it collapses completely to zero. Under stress, writing it down beats holding it in your head.</figcaption>
</figure>

Here is the reason, which we were able to measure directly:

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

<figure class="nb-fig">
  <svg viewBox="0 0 560 262" role="img" aria-label="Three different learning mechanisms all score about 92 to 93 out of 100 on the reward task, far above the coin-flip line at 50 and indistinguishable from each other.">
    <g font-family="ui-monospace, monospace" font-size="11" fill="currentColor" opacity="0.55">
      <text x="82" y="46" text-anchor="end">100</text>
      <text x="82" y="130" text-anchor="end">50</text>
      <text x="82" y="216" text-anchor="end">0</text>
    </g>
    <text x="24" y="130" font-family="ui-monospace, monospace" font-size="10" fill="currentColor" opacity="0.5" transform="rotate(-90 24 130)" text-anchor="middle">score on the reward task</text>
    <line x1="94" y1="212" x2="522" y2="212" stroke="currentColor" stroke-opacity="0.2"/>
    <line x1="94" y1="126" x2="522" y2="126" stroke="currentColor" stroke-opacity="0.28" stroke-dasharray="5 4"/>
    <g fill="#4E9F6B">
      <rect x="150" y="53" width="62" height="159" rx="7"/>
      <rect x="282" y="52" width="62" height="160" rx="7"/>
      <rect x="414" y="51" width="62" height="161" rx="7"/>
    </g>
    <g font-family="ui-monospace, monospace" font-size="11" fill="currentColor" opacity="0.85" text-anchor="middle">
      <text x="181" y="46">92.4</text>
      <text x="313" y="45">92.9</text>
      <text x="445" y="44">93.2</text>
    </g>
    <g font-family="ui-monospace, monospace" font-size="11" fill="currentColor" opacity="0.7" text-anchor="middle">
      <text x="181" y="232">activity</text>
      <text x="313" y="232">one rule</text>
      <text x="445" y="232">rule / wire</text>
    </g>
  </svg>
  <figcaption>The same three approaches that came apart under memory stress now land in exactly the same place: about 92 out of 100, well clear of the coin-flip line, and too close together to tell apart. When the task is learning-from-reward, the mechanism stops mattering.</figcaption>
</figure>

So the headline "rewiring beats remembering" is true, but only for **holding information under stress**, not for learning in general. That is a much more honest sentence than the one we started with.

## Where it lands: a machine that fixes itself

The payoff is a controller that keeps a pole balanced while a hidden fault flips its motor mid-run. A fixed controller topples. One with reward-gated rewiring *feels the pole falling and re-wires itself* to recover.

<figure class="nb-fig">
  <svg viewBox="0 0 560 250" role="img" aria-label="Recoveries after a hidden motor fault. Reward-gated rewiring recovers on 5 of 5 runs, a fixed controller on 3 of 5, and a recurrent-state controller on 0 of 5.">
    <g font-family="ui-monospace, monospace" font-size="11" fill="currentColor" opacity="0.55">
      <text x="150" y="52" text-anchor="end">5/5</text>
      <text x="150" y="200" text-anchor="end">0/5</text>
    </g>
    <line x1="160" y1="196" x2="520" y2="196" stroke="currentColor" stroke-opacity="0.2"/>
    <rect x="190" y="40" width="66" height="156" rx="7" fill="#4E9F6B"/>
    <rect x="310" y="102" width="66" height="94" rx="7" fill="currentColor" opacity="0.3"/>
    <rect x="430" y="192" width="66" height="4" rx="2" fill="#C7583F" opacity="0.55"/>
    <g font-family="ui-monospace, monospace" font-size="12" fill="currentColor" text-anchor="middle">
      <text x="223" y="32" opacity="0.9">5/5</text>
      <text x="343" y="94" opacity="0.72">3/5</text>
      <text x="463" y="186" opacity="0.9" fill="#C7583F">0/5</text>
    </g>
    <g font-family="ui-monospace, monospace" font-size="10.5" fill="currentColor" opacity="0.72" text-anchor="middle">
      <text x="223" y="218">rewiring</text>
      <text x="223" y="232">(feels + fixes)</text>
      <text x="343" y="218">fixed</text>
      <text x="343" y="232">controller</text>
      <text x="463" y="218">recurrent</text>
      <text x="463" y="232">state</text>
    </g>
  </svg>
  <figcaption>Five runs each, after a fault secretly flips the motor mid-balance. The reward-gated rewiring controller recovers every time. The fixed controller manages three of five (it stumbles onto policies that happen to span both settings). The recurrent-state controller recovers none. Rewiring is the one that reliably feels the fault and adapts.</figcaption>
</figure>

That is post-deployment adaptation, and you can watch it, evolve your own, and try to break it:

<p class="nb-cta"><a href="/research/workbench">Open the workbench and try it &rarr;</a></p>

## Read the rigorous version

None of the above asks you to take our word for it. Every claim here is a signed, dated entry in the open corpus, with the raw numbers and the statistics, including the two we retracted. Follow the *sources* under this post, or start with the [Programme 3 synthesis](https://github.com/rgfaber/faber-ecosystem/blob/master/plans/SYNTHESIS_P3.md).
