%{
  title: "Same score, same mind? We opened the box to find out",
  date: ~D[2026-07-23],
  description: "Three tiny networks learn a task equally well. Does an equal score mean they think the same way inside? We built a mind-reader to check, got fooled by our own mistake, caught it, and found the honest answer.",
  tags: ["programme-3", "meta-learning", "open-science"],
  sources: [35, 43, 44, 45, 47],
  corpus_ref: "faber insight 047 + SYNTHESIS_P3"
}
---

Three students hand in the same exam and all score 90. Do they think the same way? You cannot tell from the grade. Maybe they used the same method. Maybe they used three completely different methods that happen to land on the same number. The score is the outside. To know what is going on you have to look at their **working**.

This post is about doing exactly that to three tiny neural networks, getting the answer badly wrong on the first try, catching it, and what we found once we fixed it.

## The setup: a tie we did not understand

In [an earlier note](/research/notes/remember-or-rewire) we found that when the task is *learning* (work out which button pays off, from reward alone, and re-work it when we secretly swap the buttons), three different kinds of network all do about equally well. A network that remembers with its **activity**, one that rewires itself with a **single rule**, and one that rewires with **a rule per connection**: same score, near enough.

We had a tidy explanation for the tie. This kind of learning works by *averaging reward over many tries*, and averaging is a smoother, so we guessed it simply *blurs away* whatever makes the three networks different. Neat. Satisfying. And completely untested, because it is a claim about the **inside** of the networks, and all we had measured was the **outside** (the score).

So we opened the box.

## The mind-reader

The trick: take a trained network, let it play, and at every step peek at its internal state (the activity it is holding, or the wiring it has rewired) and ask one question. *From this alone, can I tell which button is currently the good one?* We train a small decoder to try. Score it: **1.0** means the network's insides perfectly carry that knowledge, **0.5** is a coin flip (they carry nothing), and *below 0.5* should be impossible, because it would mean the insides are reliably, informatively **wrong**.

## The part where we were wrong

The first time we ran this, it produced a bombshell. One network scored **below a coin flip** at reading its own mind. Taken at face value, it said a network was solving the task while carrying reliably-wrong gibberish inside: a genuinely exciting result, and one that would have forced us to walk back an earlier finding.

It was wrong, and it was our fault. Before we signed anything, a reviewer whose entire job is to attack our work read the *code* and found the flaw. Without meaning to, we had built the test so the mind-reader practised on one kind of day and was graded on the mirror-image kind. A reader that had learned the *real* pattern would then score perfectly **inside-out**: not random, but reversed. Our shocking "below chance" number was not an empty network. It was our own answer key printed upside-down.

We fixed the split and ran it again. The bombshell evaporated:

<figure class="nb-fig">
  <svg viewBox="0 0 560 316" role="img" aria-label="Decode accuracy for three networks. With the broken test, the scores are scattered and one falls below the 0.5 coin-flip line. After the fix, all three cluster near the top around 0.9 to 0.97.">
    <g font-family="ui-monospace, monospace" font-size="11" fill="currentColor" opacity="0.55">
      <text x="80" y="54" text-anchor="end">1.0</text>
      <text x="80" y="154" text-anchor="end">0.5</text>
      <text x="80" y="254" text-anchor="end">0.0</text>
    </g>
    <text x="20" y="158" font-family="ui-monospace, monospace" font-size="10" fill="currentColor" opacity="0.5" transform="rotate(-90 20 158)" text-anchor="middle">mind-reader score</text>
    <line x1="92" y1="50" x2="524" y2="50" stroke="currentColor" stroke-opacity="0.08"/>
    <line x1="92" y1="250" x2="524" y2="250" stroke="currentColor" stroke-opacity="0.12"/>
    <line x1="92" y1="150" x2="524" y2="150" stroke="currentColor" stroke-opacity="0.28" stroke-dasharray="5 4"/>
    <text x="524" y="144" text-anchor="end" font-family="ui-monospace, monospace" font-size="10.5" fill="currentColor" opacity="0.5">coin flip (0.5) — carries nothing</text>
    <g stroke="currentColor" stroke-opacity="0.28" stroke-width="2">
      <line x1="175" y1="192" x2="175" y2="57"/>
      <line x1="308" y1="128" x2="308" y2="68"/>
      <line x1="441" y1="92" x2="441" y2="59"/>
    </g>
    <g>
      <circle cx="175" cy="192" r="6.5" fill="#C7583F"/>
      <circle cx="175" cy="57" r="6.5" fill="#4E9F6B"/>
      <circle cx="308" cy="128" r="6.5" fill="#C7583F"/>
      <circle cx="308" cy="68" r="6.5" fill="#4E9F6B"/>
      <circle cx="441" cy="92" r="6.5" fill="#C7583F"/>
      <circle cx="441" cy="59" r="6.5" fill="#4E9F6B"/>
    </g>
    <g font-family="ui-monospace, monospace" font-size="11" fill="currentColor">
      <text x="189" y="196" opacity="0.7">0.29</text>
      <text x="189" y="53" opacity="0.9">0.965</text>
      <text x="322" y="132" opacity="0.7">0.61</text>
      <text x="322" y="64" opacity="0.9">0.908</text>
      <text x="455" y="96" opacity="0.7">0.79</text>
      <text x="455" y="55" opacity="0.9">0.956</text>
    </g>
    <g font-family="ui-monospace, monospace" font-size="11" fill="currentColor" opacity="0.75" text-anchor="middle">
      <text x="175" y="274">activity</text>
      <text x="308" y="274">one rule</text>
      <text x="441" y="274">rule / wire</text>
    </g>
    <g font-family="ui-monospace, monospace" font-size="11">
      <circle cx="120" cy="300" r="5.5" fill="#C7583F"/><text x="133" y="304" fill="currentColor" opacity="0.7">first run (broken test)</text>
      <circle cx="360" cy="300" r="5.5" fill="#4E9F6B"/><text x="373" y="304" fill="currentColor" opacity="0.7">after the fix</text>
    </g>
  </svg>
  <figcaption>Reading each network's mind, before and after we fixed our own test. Broken (terracotta): scattered, one network reads *below* a coin flip, the tell-tale sign of an upside-down answer key. Fixed (green): all three cluster near the top, and the one that had "scored below random" is now the strongest reader of the lot.</figcaption>
</figure>

We kept the broken run on the record, right next to the corrected one, and retracted nothing, because the finding we had been about to walk back was never actually wrong.

## What the fixed test showed

With the answer key the right way up, the honest picture appears: **all three networks read the good button beautifully, and almost identically** (0.91 to 0.97). Their insides are not different-things-blurred-into-agreement. They are the same skill, arrived at three separate ways.

Which quietly kills our own earlier guess. The networks do not tie because a smoother *blurs away* their differences. They tie because there are **no differences to blur**: each independently learns the same good habit of tracking which button pays.

## One more trap: reading, or just a stopwatch?

A sceptic could still object. We always swapped the buttons at the same moment. What if a network is not reading the world at all, just running an internal *stopwatch* ("switch at the halfway mark") that happens to line up? Same score, no actual thinking.

Cheap to check: move the swap. Make it early (trial 20) or late (trial 40) instead of the trained halfway point (30), and see whether performance holds.

<figure class="nb-fig">
  <svg viewBox="0 0 560 300" role="img" aria-label="Fitness of each network when the button-swap is moved to trial 20, 30, or 40. The three learning networks stay flat and high; a purely reactive network stays flat and lower; a hypothetical internal clock would peak at 30 and fall away.">
    <g font-family="ui-monospace, monospace" font-size="11" fill="currentColor" opacity="0.55">
      <text x="86" y="58" text-anchor="end">90</text>
      <text x="86" y="150" text-anchor="end">82</text>
      <text x="86" y="230" text-anchor="end">75</text>
    </g>
    <text x="24" y="150" font-family="ui-monospace, monospace" font-size="10" fill="currentColor" opacity="0.5" transform="rotate(-90 24 150)" text-anchor="middle">how well it scores</text>
    <g stroke="currentColor" stroke-opacity="0.1"><line x1="98" y1="54" x2="500" y2="54"/><line x1="98" y1="230" x2="500" y2="230"/></g>
    <g font-family="ui-monospace, monospace" font-size="11" fill="currentColor" opacity="0.6" text-anchor="middle">
      <text x="140" y="256">swap at 20</text>
      <text x="300" y="256">swap at 30</text>
      <text x="460" y="256">swap at 40 (trained here: 30)</text>
    </g>
    <polyline points="140,170 300,96 460,170" fill="none" stroke="#C7583F" stroke-width="2" stroke-dasharray="6 5" stroke-opacity="0.6"/>
    <text x="300" y="82" text-anchor="middle" font-family="ui-monospace, monospace" font-size="10" fill="#C7583F" opacity="0.85">a clock would peak here, then fall away</text>
    <polyline points="140,102 300,90 460,94" fill="none" stroke="#4E9F6B" stroke-width="2.5"/>
    <polyline points="140,110 300,100 460,88" fill="none" stroke="#4E9F6B" stroke-width="2.5" stroke-opacity="0.75"/>
    <polyline points="140,128 300,129 460,110" fill="none" stroke="#4E9F6B" stroke-width="2.5" stroke-opacity="0.55"/>
    <polyline points="140,175 300,181 460,177" fill="none" stroke="currentColor" stroke-opacity="0.4" stroke-width="2" stroke-dasharray="2 3"/>
    <g font-family="ui-monospace, monospace" font-size="10.5" fill="currentColor">
      <text x="470" y="92" fill="#4E9F6B" opacity="0.9">the three</text>
      <text x="470" y="104" fill="#4E9F6B" opacity="0.9">networks</text>
      <text x="470" y="181" opacity="0.55">reflex-only</text>
    </g>
    <g font-family="ui-monospace, monospace" font-size="11">
      <line x1="120" y1="286" x2="140" y2="286" stroke="#4E9F6B" stroke-width="2.5"/><text x="148" y="290" fill="currentColor" opacity="0.7">the learning networks (flat = they track the swap)</text>
    </g>
  </svg>
  <figcaption>Move the swap and the three learning networks (green) barely flinch: they adapt wherever it happens, no worse than a purely reflexive network (grey) with no clock to keep. A network relying on an internal stopwatch would instead peak at the trained time and fall away (terracotta, dashed): we see no such peak. Genuine reading, not a memorised beat.</figcaption>
</figure>

## Where it lands

The machines converge because they each learn the same real skill, not because a filter hides how they differ. That is a smaller, sturdier sentence than the one we started with, and we reached it by looking inside instead of trusting the score.

The part we are proudest of is not the result. It is that the mistake in the first version was caught by a check built to catch exactly that, before it hardened into a published claim. [Publishing our failures](/research/notes/why-we-publish-our-failures) is the visible half of honest science. Building the checks that catch them early is the other half, and this is the first time one paid for itself in a single afternoon.

## Read the rigorous version

Every number here is a signed, dated entry in the open corpus, including the upside-down run we kept. Follow the *sources* under this post, or start with the [Programme 3 synthesis](https://codeberg.org/rgfaber/faber-ecosystem/src/branch/master/plans/SYNTHESIS_P3.md).
