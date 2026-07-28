%{
  title: "Abandoning the objective: when chasing the goal is how you fail",
  date: ~D[2026-07-23],
  description: "Some problems are traps: aiming straight at the goal walks you into a dead end, and a stronger optimiser just gets there faster. We built one such trap on purpose and watched a search that ignores the goal entirely walk out of it — after a bug nearly convinced us otherwise.",
  tags: ["programme-4", "quality-diversity", "open-science"],
  sources: [50, 51, 52],
  corpus_ref: "faber insights 050-052 + CHARTER_P4_OBJECTIVES"
}
---

Here is an idea that sounds wrong the first time you hear it: for some problems, the surest way to fail is to aim directly at the goal. Not because you are lazy or slow, but because the landscape is a **trap** — every step that looks like progress walks you deeper into a dead end. Push harder and you just hit the wall faster.

If that is true, the fix is not a stronger engine. It is a different thing to want. Instead of rewarding *getting closer to the goal*, you reward *doing something new*. Chase novelty, ignore the objective, and — the claim goes — you wander out of the trap the goal-chaser is stuck in. This is a famous idea in evolutionary computing (Lehman & Stanley called it "abandoning objectives"). This programme set out to see it happen for ourselves, on our own engine. It took two experiments, and a caught mistake, to do it honestly.

## First, a warm-up that told us the task matters

Before testing traps, we built the machinery on a friendly problem: balancing a pole on a cart. The novelty-style method here is **MAP-Elites**, which does not chase one best answer — it fills a shelf with *many kinds* of answer (balancers that lean left, lean right, drift up-track, down-track). At an equal compute budget, it did fill that shelf better than plain random tinkering:

<figure class="nb-fig">
  <svg viewBox="0 0 560 280" role="img" aria-label="Kinds of successful balancer found at equal budget: MAP-Elites found 104, plain random search found 74. A note records that both reached the same maximum score.">
    <g font-family="ui-monospace, monospace" font-size="11" fill="currentColor" opacity="0.55">
      <text x="150" y="250" text-anchor="middle">MAP-Elites</text>
      <text x="390" y="250" text-anchor="middle">random search</text>
    </g>
    <text x="26" y="130" font-family="ui-monospace, monospace" font-size="10" fill="currentColor" opacity="0.5" transform="rotate(-90 26 130)" text-anchor="middle">different kinds of balancer found</text>
    <line x1="70" y1="230" x2="520" y2="230" stroke="currentColor" stroke-opacity="0.25"/>
    <rect x="96" y="54" width="108" height="176" rx="5" fill="#4E9F6B"/>
    <rect x="336" y="105" width="108" height="125" rx="5" fill="currentColor" opacity="0.28"/>
    <g font-family="ui-monospace, monospace" font-size="15" font-weight="bold">
      <text x="150" y="44" text-anchor="middle" fill="#4E9F6B">104</text>
      <text x="390" y="95" text-anchor="middle" fill="currentColor" opacity="0.6">74</text>
    </g>
    <text x="290" y="270" text-anchor="middle" font-family="ui-monospace, monospace" font-size="10.5" fill="currentColor" opacity="0.6">…but both hit the same top score.</text>
  </svg>
  <figcaption>The warm-up (insight 050). At the same budget, the diversity-seeking method fills its shelf with ~40% more distinct kinds of balancer (104 vs 74). But the honest catch: the pole is easy, every method reaches the maximum score, so there is no higher *peak* to win — only a fuller *collection*. To test whether diversity finds a peak that goal-chasing cannot, we needed a genuinely hard, deceptive task.</figcaption>
</figure>

That warm-up also handed us our first lesson in self-doubt. A first pass had screamed "diversity beats goal-chasing twenty-fold!" — but the reviewer whose job is to attack our work found it was comparing against a broken baseline (a single greedy run that stalls badly), while random tinkering already aced the task. We retracted the twenty-fold claim before it was ever signed. Coverage was the real, modest win; the headline was an artifact.

## Then we built the trap

So we built a small maze designed to be **deceptive**. Start at one corner, goal near another. The catch: a barrier sits so that the cells *closest* to the goal form a cul-de-sac. To actually reach the goal you must first walk **away** from it, around the barrier. A searcher rewarded for "get nearer the goal" is lured straight into the dead end and cannot leave — every exit move scores worse.

We ran five searchers on it, each given the same mutation and the same budget, forty independent runs apiece:

<figure class="nb-fig">
  <svg viewBox="0 0 560 320" role="img" aria-label="Solve rate on the deceptive maze out of 40 runs. Goal-chasing solved 1, a strong optimiser solved 0, random search solved 4, novelty-by-path solved 24, and novelty-by-endpoint solved 34.">
    <line x1="200" y1="44" x2="200" y2="266" stroke="currentColor" stroke-opacity="0.25"/>
    <line x1="520" y1="44" x2="520" y2="266" stroke="currentColor" stroke-opacity="0.1" stroke-dasharray="4 4"/>
    <text x="520" y="40" text-anchor="end" font-family="ui-monospace, monospace" font-size="10" fill="currentColor" opacity="0.45">40 / 40</text>
    <g font-family="ui-monospace, monospace" font-size="11.5">
      <!-- goal-chasing: 1/40 -->
      <text x="190" y="66" text-anchor="end" fill="currentColor" opacity="0.75">goal-chasing</text>
      <rect x="200" y="54" width="8" height="24" rx="3" fill="#C7583F"/>
      <text x="216" y="72" fill="#C7583F" opacity="0.9">1 / 40 — trapped</text>
      <!-- strong optimiser: 0/40 -->
      <text x="190" y="106" text-anchor="end" fill="currentColor" opacity="0.75">a stronger optimiser</text>
      <rect x="200" y="94" width="3" height="24" rx="1.5" fill="#C7583F" opacity="0.85"/>
      <text x="216" y="112" fill="#C7583F" opacity="0.9">0 / 40 — also trapped</text>
      <!-- random: 4/40 -->
      <text x="190" y="146" text-anchor="end" fill="currentColor" opacity="0.75">random tinkering</text>
      <rect x="200" y="134" width="32" height="24" rx="3" fill="currentColor" opacity="0.3"/>
      <text x="240" y="152" fill="currentColor" opacity="0.6">4 / 40</text>
      <!-- novelty by path: 24/40 -->
      <text x="190" y="186" text-anchor="end" fill="currentColor" opacity="0.75">novelty (new paths)</text>
      <rect x="200" y="174" width="192" height="24" rx="3" fill="#4E9F6B" opacity="0.72"/>
      <text x="400" y="192" fill="#4E9F6B" opacity="0.9">24 / 40</text>
      <!-- novelty by endpoint: 34/40 -->
      <text x="190" y="226" text-anchor="end" fill="currentColor" opacity="0.75">novelty (new end-spots)</text>
      <rect x="200" y="214" width="272" height="24" rx="3" fill="#4E9F6B"/>
      <text x="480" y="232" fill="#4E9F6B" font-weight="bold">34 / 40</text>
    </g>
    <line x1="200" y1="256" x2="520" y2="256" stroke="currentColor" stroke-opacity="0.2"/>
    <text x="200" y="290" font-family="ui-monospace, monospace" font-size="10.5" fill="currentColor" opacity="0.65">Twin maze (no trap): goal-chasing solves 40/40.</text>
    <text x="200" y="306" font-family="ui-monospace, monospace" font-size="10.5" fill="currentColor" opacity="0.65">So the trap stops it, not the difficulty.</text>
  </svg>
  <figcaption>The trap (insight 051), 40 runs each. Goal-chasing solves it once; a genuinely strong optimiser, zero — strength does not help, it climbs faster into the dead end. Reward novelty instead and the maze opens up: 24/40 rewarding new *paths*, 34/40 rewarding new *end-spots*. The control that makes it a fair test: on a twin maze with the barrier moved so the direct route works, goal-chasing scores a perfect 40/40. The method is not the difference. The trap is.</figcaption>
</figure>

Read the bottom two bars against the top two and the old idea is right in front of you. **The searcher that ignores the goal walks out of the trap the goal-chaser is stuck in.** And note the middle bar: a *stronger* optimiser did no better than the weak one — worse, even. Deception is not a horsepower problem. A better goal-chaser just reaches the dead end sooner. The only thing that helped was wanting something different.

## The bug that nearly hid it

The honest part: our **first** run of this said the opposite. Novelty scored a miserable 2 out of 40 — worse than random. We could have signed "novelty does not help on deception" and moved on. The reviewer read the code first and found the flaw: the routine that is supposed to reward being *different* from the crowd had a bug that quietly cancelled its own anti-sameness pressure, and we had rewarded the wrong kind of "new" (novel wiggles that never leave the trap's basin). Fix the bug, reward new **end-spots** instead of new paths, and the 2/40 became 34/40. The result did not change because we wanted it to. It changed because the first measurement was broken, and the check caught it before it hardened.

That is the same story as the [mind-reader post](/research/notes/same-score-same-mind), and it keeps happening for a reason: the reviewer's only job is to try to *refute* our results, in advance of signing. It has now flipped or killed a result eight times this season. A false negative — nearly throwing away a true finding — is exactly the kind of mistake that is invisible unless something is built to look for it.

## Where it lands

Programme 4 asks what happens when you change *what fitness rewards*. The answer, demonstrated on our own engine: when a landscape is deceptive, changing the **selection pressure** — reward novelty, not proximity — solves what no amount of optimiser strength can. Which *kind* of novelty you reward matters too (end-spots beat paths here), a knob for the next experiments. And the open question left standing: when the goal-chaser *can* solve a task, does novelty cost more tries to get there? That efficiency question is next.

## The sequel: does wanting-something-different cost you when chasing the goal already works?

That was the open question, and we answered it. We built the *non-deceptive* twin maze, where chasing the goal wins outright, and asked the obvious "no free lunch" question: surely rewarding novelty instead of proximity costs something here? A tax in wasted tries?

It didn't show up. Novelty reached the goal about as fast as the goal-chaser (neither meaningfully slower), both far quicker than random tinkering, and along the way novelty explored almost the entire maze while the goal-chaser walked a narrow line to the exit.

<figure class="nb-fig">
  <svg viewBox="0 0 560 250" role="img" aria-label="On the non-deceptive maze: how much of the maze each search explored (novelty 112 of about 112 cells, goal-chasing 79, random 68) and how fast each reached the goal (novelty 268 evaluations, goal-chasing 305, random 690).">
    <text x="16" y="30" font-family="ui-monospace, monospace" font-size="11" fill="currentColor" opacity="0.55">how much of the maze it explored (of ~112 cells)</text>
    <g font-family="ui-monospace, monospace" font-size="11.5">
      <text x="150" y="58" text-anchor="end" fill="currentColor" opacity="0.75">novelty</text>
      <rect x="160" y="46" width="336" height="16" rx="3" fill="#4E9F6B"/>
      <text x="504" y="59" fill="#4E9F6B" font-weight="bold">112</text>
      <text x="150" y="82" text-anchor="end" fill="currentColor" opacity="0.75">goal-chasing</text>
      <rect x="160" y="70" width="237" height="16" rx="3" fill="currentColor" opacity="0.35"/>
      <text x="405" y="83" fill="currentColor" opacity="0.6">79</text>
      <text x="150" y="106" text-anchor="end" fill="currentColor" opacity="0.75">random</text>
      <rect x="160" y="94" width="204" height="16" rx="3" fill="currentColor" opacity="0.25"/>
      <text x="372" y="107" fill="currentColor" opacity="0.5">68</text>
    </g>
    <line x1="160" y1="130" x2="500" y2="130" stroke="currentColor" stroke-opacity="0.12"/>
    <text x="16" y="158" font-family="ui-monospace, monospace" font-size="11" fill="currentColor" opacity="0.55">tries to reach the goal (fewer = faster; median)</text>
    <g font-family="ui-monospace, monospace" font-size="11.5">
      <text x="150" y="186" text-anchor="end" fill="currentColor" opacity="0.75">novelty</text>
      <rect x="160" y="174" width="86" height="16" rx="3" fill="#4E9F6B" opacity="0.8"/>
      <text x="254" y="187" fill="#4E9F6B" opacity="0.9">268</text>
      <text x="150" y="210" text-anchor="end" fill="currentColor" opacity="0.75">goal-chasing</text>
      <rect x="160" y="198" width="98" height="16" rx="3" fill="currentColor" opacity="0.35"/>
      <text x="266" y="211" fill="currentColor" opacity="0.6">305</text>
      <text x="150" y="234" text-anchor="end" fill="currentColor" opacity="0.75">random</text>
      <rect x="160" y="222" width="221" height="16" rx="3" fill="currentColor" opacity="0.25"/>
      <text x="389" y="235" fill="currentColor" opacity="0.5">690</text>
    </g>
  </svg>
  <figcaption>The efficiency question (insight 052, 120 runs). Top: novelty explores almost the whole maze (112 of ~112 cells) while goal-chasing walks a narrow route (79) and random barely moves (68). Bottom: yet novelty reaches the goal about as fast as goal-chasing (268 vs 305 tries, a difference lost in the noise), both far faster than random (690). The predicted speed tax did not appear.</figcaption>
</figure>

Two honest cautions. We could not prove the two are *exactly* equal in speed (our measurement stayed a little too fuzzy for that even after tripling the runs), so we sign the *absence* of a penalty, not perfect parity. And the coverage win is flattered by a small maze that novelty can fill completely. But the headline holds: here, wanting-something-different cost nothing and bought a lot. Which is the perfect setup for the next programme, where the world stops having a single goal — and coverage stops being a bonus and becomes the whole point.

## Read the rigorous version

Every number here is a signed, dated entry in the open corpus — including the retracted twenty-fold claim and the buggy first run, both kept on the record. Follow the *sources* under this post, or start with the [Programme 4 charter](https://github.com/rgfaber/faber-ecosystem/blob/master/plans/CHARTER_P4_OBJECTIVES.md) and the [signed insights index](https://github.com/rgfaber/faber-ecosystem/blob/master/insights/INDEX.md).
