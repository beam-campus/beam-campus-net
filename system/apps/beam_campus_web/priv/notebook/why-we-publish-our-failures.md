%{
  title: "Why we publish our failures",
  date: ~D[2026-07-23],
  description: "Most research quietly buries the experiments that didn't work. We publish every one, signed and dated, including the two theories we killed and the three experiments that found nothing. Here is why that is better science, not worse.",
  tags: ["method", "commons", "open-science"],
  sources: [24, 26, 38, 40, 43, 44, 45, 46],
  corpus_ref: "faber insights 024 to 046"
}
---

There is a quiet rot in most science, and it has a name: the **file-drawer problem**. An experiment that "doesn't work" (a negative result, an inconclusive one, a refuted hunch) goes in a drawer and is never seen. Only the wins get written up. So everyone reads the successes, nobody reads the dead ends, the same mistakes get repeated across labs, and effects look far stronger and cleaner than they really are.

We do the opposite, on purpose. Every experiment we run gets a signed, numbered, dated entry in an open corpus, whether it confirmed our hunch, refuted it flatly, or landed in a shrug. This post is about why, and what it actually looks like when you commit to it.

<figure class="nb-fig">
  <svg viewBox="0 0 520 200" role="img" aria-label="Most labs publish only the successes; the open notebook shows every result, including refutations and corrections.">
    <text x="10" y="22" font-family="ui-monospace, monospace" font-size="12" fill="currentColor" opacity="0.65">what usually gets published</text>
    <g>
      <rect x="10" y="34" width="20" height="20" rx="4" fill="#4E9F6B"/>
      <rect x="40" y="34" width="20" height="20" rx="4" fill="currentColor" opacity="0.09"/>
      <rect x="70" y="34" width="20" height="20" rx="4" fill="#4E9F6B"/>
      <rect x="100" y="34" width="20" height="20" rx="4" fill="currentColor" opacity="0.09"/>
      <rect x="130" y="34" width="20" height="20" rx="4" fill="currentColor" opacity="0.09"/>
      <rect x="160" y="34" width="20" height="20" rx="4" fill="#4E9F6B"/>
      <rect x="190" y="34" width="20" height="20" rx="4" fill="currentColor" opacity="0.09"/>
      <rect x="220" y="34" width="20" height="20" rx="4" fill="currentColor" opacity="0.09"/>
      <rect x="250" y="34" width="20" height="20" rx="4" fill="#4E9F6B"/>
      <rect x="280" y="34" width="20" height="20" rx="4" fill="currentColor" opacity="0.09"/>
      <rect x="310" y="34" width="20" height="20" rx="4" fill="currentColor" opacity="0.09"/>
      <rect x="340" y="34" width="20" height="20" rx="4" fill="currentColor" opacity="0.09"/>
      <rect x="370" y="34" width="20" height="20" rx="4" fill="#4E9F6B"/>
      <rect x="400" y="34" width="20" height="20" rx="4" fill="currentColor" opacity="0.09"/>
    </g>
    <text x="10" y="112" font-family="ui-monospace, monospace" font-size="12" fill="currentColor" opacity="0.65">the open notebook</text>
    <g>
      <rect x="10" y="124" width="20" height="20" rx="4" fill="#4E9F6B"/>
      <rect x="40" y="124" width="20" height="20" rx="4" fill="#C7583F"/>
      <rect x="70" y="124" width="20" height="20" rx="4" fill="#4E9F6B"/>
      <rect x="100" y="124" width="20" height="20" rx="4" fill="#C7583F"/>
      <rect x="130" y="124" width="20" height="20" rx="4" fill="#F2B142"/>
      <rect x="160" y="124" width="20" height="20" rx="4" fill="#4E9F6B"/>
      <rect x="190" y="124" width="20" height="20" rx="4" fill="#C7583F"/>
      <rect x="220" y="124" width="20" height="20" rx="4" fill="#C7583F"/>
      <rect x="250" y="124" width="20" height="20" rx="4" fill="#4E9F6B"/>
      <rect x="280" y="124" width="20" height="20" rx="4" fill="#F2B142"/>
      <rect x="310" y="124" width="20" height="20" rx="4" fill="#C7583F"/>
      <rect x="340" y="124" width="20" height="20" rx="4" fill="#C7583F"/>
      <rect x="370" y="124" width="20" height="20" rx="4" fill="#4E9F6B"/>
      <rect x="400" y="124" width="20" height="20" rx="4" fill="#C7583F"/>
    </g>
    <g font-family="ui-monospace, monospace" font-size="10.5" fill="currentColor" opacity="0.6">
      <rect x="10" y="164" width="12" height="12" rx="3" fill="#4E9F6B"/><text x="27" y="174">confirmed</text>
      <rect x="110" y="164" width="12" height="12" rx="3" fill="#C7583F"/><text x="127" y="174">refuted / null</text>
      <rect x="235" y="164" width="12" height="12" rx="3" fill="#F2B142"/><text x="252" y="174">corrected</text>
    </g>
  </svg>
  <figcaption>Same experiments, two publishing habits. The drawer is where good evidence goes to be forgotten.</figcaption>
</figure>

## What "publishing failures" actually looks like

Not a slogan. Concrete, from our own notebook, with the receipts:

- **We contradicted ourselves, and left the trail.** We reported that one memory mechanism was hopeless at holding two things at once. A week later we realised it was a *testing mistake* on our part, not a real limit. Insight 038 does not quietly overwrite the earlier claim; it corrects it in the open, so the whole reasoning stays visible.
- **We killed our own favourite theory.** We had an elegant explanation for a result and built an experiment *specifically to confirm it*. It refuted it flatly. Insight 040 is, in effect, titled "our nice theory was wrong."
- **We published three nothings in a row.** On one question, three separate experiments (043, 044, 045) each found no difference between the things we were comparing. A conventional paper buries a single null; three would never see daylight. For us they *were* the finding: they revealed the thing we cared about belongs to a different regime entirely.
- **We caught ourselves believing a fluke.** An early result looked spectacular, from a single run. Our own rule (no claim about a *rate* below ten runs) forced a rerun. It did not survive. Insight 026 keeps both the exciting fluke and its quiet death.

## The discipline that makes it cheap and safe

Publishing failures only works if the format removes the sting:

- **Signed, numbered, never deleted.** Entries are monotonic. You supersede an old one by writing a new one that references it. You never edit history.
- **Evidence or it didn't happen.** Every claim cites a measurement, or a file and a line.
- **Negatives are first-class.** A refuted expectation gets the same care in the write-up as a confirmed one. Often it gets more.
- **Report as replication, not discovery.** When we reproduce something already known, we say so plainly. No inflating a re-run into a breakthrough.

## Why a commons, specifically, does it this way

A company has an incentive to show only its wins: the story is the product. A commons has the exact opposite incentive. The whole point is that other people can build on ground that is *actually* solid. A buried negative is a trap left for the next person to step in. A published one is a gift to them.

So this is not modesty, and it is not confession. It is just better engineering, and it happens to be the only honest way to invite people in.

## Come check our work

All of it is open. The corpus is signed and dated. The [interactive demos](/research/workbench) let you reproduce the headline results with your own hands. The two claims we retracted are still there, labelled as such. If you go through it and find us wrong, that is not an embarrassment to us. That is the system doing exactly what it is for.

Start anywhere: the [notebook](/research/notes), or the [signed insights](https://codeberg.org/rgfaber/faber-ecosystem/src/branch/master/insights/INDEX.md) themselves.
