%{
  title: "Running to stay in place: when the scoreboard lies",
  date: ~D[2026-07-23],
  description: "In a contest where both sides keep improving, the head-to-head score can read 50-50 forever, hiding real progress in plain sight. We built the smallest possible version to watch it happen, because we need a ruler we trust before the interesting games begin.",
  corpus: :faber,
  tags: ["programme-7", "coevolution", "open-science"],
  sources: [53],
  corpus_ref: "faber insight 053 + CHARTER_P7_COEVOLUTION"
}
---

In *Through the Looking-Glass*, the Red Queen tells Alice: "it takes all the running you can do, to keep in the same place." A biologist, Leigh Van Valen, borrowed the line for evolution. When two species compete, each is the other's world. Predators get faster, so prey get faster, so predators get faster again. Everyone improves, and yet relative to each other, nobody pulls ahead. All that running, same place.

This is where our seventh line of research begins, and it comes with a nasty measurement trap that we wanted to stare at directly before anything fancy.

## The trap

So far, every experiment on this site has measured a machine against a *fixed* task: balance this pole, escape this maze. The score means something because the task holds still. Coevolution breaks that. When you evolve two populations that compete, and you measure "how well is population A doing against population B right now," the yardstick is *moving*. B is evolving too.

Here is the trap in one sentence: **both sides can be getting genuinely, dramatically better, while the score between them sits at 50-50 the entire time.** If you only watch that score, you conclude nothing is happening. You would be completely wrong.

## The smallest possible demonstration

We did not want to argue about this. We wanted to *see* it, on a case so simple that the truth is impossible to miss. So the "strategy" of each player is just a single number. Bigger numbers tend to beat smaller ones (gently, not absolutely). Two populations of numbers coevolve, each trying to beat the other.

What happens is not subtle. The numbers climb, and climb, without limit, generation after generation. That climb is *real progress you can read with your own eyes*. And the head-to-head score between the two populations never budges from 50-50.

<figure class="nb-fig">
  <svg viewBox="0 0 560 290" role="img" aria-label="Over 150 generations, the champion's number rises steadily from 50 to 86 (real progress), while the head-to-head score against the current rival stays flat at 50-50 the whole time.">
    <g font-family="ui-monospace, monospace" font-size="11" fill="currentColor" opacity="0.55">
      <text x="86" y="52" text-anchor="end">86</text>
      <text x="86" y="234" text-anchor="end">50</text>
    </g>
    <text x="30" y="150" font-family="ui-monospace, monospace" font-size="10" fill="#4E9F6B" opacity="0.85" transform="rotate(-90 30 150)" text-anchor="middle">the champion's number</text>
    <line x1="96" y1="232" x2="500" y2="232" stroke="currentColor" stroke-opacity="0.2"/>
    <!-- rising champion number (left axis: 50..86) -->
    <polyline points="96,224 136,207 176,190 216,173 256,156 296,139 336,122 376,105 416,86 456,66 500,52" fill="none" stroke="#4E9F6B" stroke-width="2.5"/>
    <text x="300" y="96" font-family="ui-monospace, monospace" font-size="10.5" fill="#4E9F6B" opacity="0.9">real progress: keeps climbing</text>
    <!-- flat head-to-head score, annotated reference (not on the number axis) -->
    <polyline points="96,178 136,176 176,180 216,177 256,179 296,176 336,178 376,180 416,177 456,178 500,179" fill="none" stroke="#C7583F" stroke-width="2.5"/>
    <text x="150" y="168" font-family="ui-monospace, monospace" font-size="10.5" fill="#C7583F" opacity="0.9">head-to-head score: flat at 50–50 forever</text>
    <text x="298" y="264" text-anchor="middle" font-family="ui-monospace, monospace" font-size="10.5" fill="currentColor" opacity="0.5">150 generations →</text>
  </svg>
  <figcaption>The Red Queen, in the smallest game we could build (insight 053, 30 runs). Green (read against the axis): the champion's number climbs from 50 to 86, a clean unbounded arms race, real progress anyone can see. Terracotta: the head-to-head score against the current rival stays pinned at 50–50 the whole time (drawn as a flat reference, not on the number axis). Watch only the score and you would swear nothing is improving. The score does not measure progress; it measures who is momentarily ahead, and both are ahead together.</figcaption>
</figure>

## Why this is the whole point

The lesson is a rule we will carry through everything that comes next: **to measure progress in a competition, never use the score against your current opponent.** Use a *fixed* yardstick. Freeze an old opponent, or a hand-built reference, and measure against *that*. The frozen ruler does not run alongside you, so it can tell you how far you have actually come.

Why prove something so small and so obvious-sounding? Because the games we are building toward are not obvious at all: predators chasing prey, and eventually a little 2D world where creatures forage and compete and evolve on their own. In those, the truth is *hidden*. You cannot read progress off a single number. If our ruler is broken, we would never know. So we validated the ruler here, on the one game where we can also see the truth directly, and confirmed it agrees. Boring on purpose. A trustworthy instrument, checked on a known length before we measure the unknown.

We also did not pick this starting point ourselves. Our in-house critic, whose only job is to attack our plans, vetoed our first idea (jump straight to predators and prey) precisely because we would not have been able to tell a real result from a broken instrument. It sent us back to the numbers. That is the adversary [we wrote about before](/research/notes/why-we-publish-our-failures), earning its keep again.

## What comes next

This is rung one of a deliberately gentle climb: next the same test where the truth is no longer a single readable number, then games that can loop instead of progress, then games where one side runs away and the other gives up, and finally the predators and prey. Each a small, signed step. The destination is a living 2D world; the discipline is refusing to run before we can measure.

## Read the rigorous version

Every number here is a signed, dated entry in the open corpus, including the exploratory first run we discarded and kept on the record. Follow the *sources* under this post, or start with the [Programme 7 charter](https://github.com/rgfaber/faber-ecosystem/blob/master/plans/CHARTER_P7_COEVOLUTION.md) and the [signed insights index](https://github.com/rgfaber/faber-ecosystem/blob/master/insights/INDEX.md).
