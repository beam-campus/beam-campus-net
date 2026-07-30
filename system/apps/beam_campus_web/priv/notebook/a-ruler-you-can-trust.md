%{
  title: "A ruler you can trust: three ways to measure an arms race wrong",
  date: ~D[2026-07-23],
  description: "Before you can study two rivals driving each other to improve, you need a way to tell real progress from noise. We built the ruler and then tried to break it three times: a ruler too weak to read, a ruler that rewards the wrong thing, and a race that runs in circles. Each failure is a rule we now keep.",
  corpus: :faber,
  tags: ["programme-7", "coevolution", "open-science"],
  sources: [54, 55, 56],
  corpus_ref: "faber insights 054-056 + CHARTER_P7_COEVOLUTION"
}
---

In the last note (["Running to stay in place"](/research/notes/running-to-stay-in-place)) we hit a problem. When two rivals both keep improving, the head-to-head scoreboard reads 50-50 forever and hides the real progress. The fix sounded simple: stop measuring the rivals against **each other**, and measure each one against a **fixed** yardstick that never changes. A frozen opponent. A ruler.

But a ruler is a piece of measuring equipment, and measuring equipment can be wrong in quiet, dangerous ways. Before we let a ruler decide whether real neural networks are learning to outwit each other, we spent three experiments trying to break it. Each break taught us a rule. Here they are.

## Trap one: a ruler too short to read (insight 054)

Imagine measuring a growing child with a ruler that only goes up to one metre. For the first few years it works. Then the child passes one metre and the ruler reads "max" forever. The child keeps growing; your ruler has gone blind.

A weak fixed opponent does exactly this. If your yardstick is easy to beat, then early on it separates a poor player from a decent one. But once your players get good enough to beat it every time, the yardstick pins at "100%" and stops moving, even as the players keep getting better. It **saturates**.

We built this on purpose. A weak reference set went blind after the players had made only about 13% of the progress they would eventually make; it was deaf to the remaining 31 of 35 units of improvement. A **graded** yardstick, one with easy rungs and hard rungs, tracked the whole climb.

The rule: a fixed ruler is not enough. It has to be **graded**, hard enough at the top that the best players still cannot max it out.

## Trap two: a ruler that rewards the wrong thing (insight 055)

Now a subtler failure. Suppose the thing you truly care about is a chain: it is only as strong as its weakest link. A good player has to be strong on **every** dimension at once. But the score you actually select on is an **average** across dimensions. Average and weakest-link are not the same, and the gap between them is where trouble hides.

Here is the twist we found: whether that gap matters **depends on the cost of improving each dimension**. When every dimension is equally cheap to improve, selecting on the average is basically harmless; the player ends up strong everywhere anyway. But make one dimension cheap and another expensive, and the average-based score quietly cheats. It pumps the cheap dimension, racks up a great-looking average, and **abandons** the expensive weakest link, exactly the link that decides real quality. The proxy and the truth come apart, but only under uneven costs.

The rule: the yardstick has to be **aligned** with what you actually care about, and reward misalignment is not always visible. It can stay hidden until the costs go lopsided.

## Trap three: a race that runs in circles (insight 056)

The nastiest failure is not a bad ruler; it is a race where "better" does not exist.

Think rock-paper-scissors. Rock beats scissors, scissors beats paper, paper beats rock. There is no best move. A population evolving on a game like this does not climb; it **rotates**. Rock strategies take over, which makes paper strategies win, which makes scissors win, which brings rock back. Round and round, forever, going nowhere.

We built a game engineered to do this and watched the population turn roughly eight full circles. The question was: does our fixed ruler get **fooled** by all that motion and report a fake climb? Good news: no. The ruler stayed honest, its reading wobbled up and down but showed no net progress, correctly, because there was none. But it was also **blind**: from the ruler alone you could never tell the difference between "stuck, going nowhere" and "going in circles." Those are very different diagnoses.

To see the circle you need a different instrument: a **tournament of champions across time**. Save a snapshot every so often, then play every past champion against every other. If later always beats earlier, that is real progress. If you find loops, champion A beats B beats C beats A, that is cycling. In the circular game we found 1055 such loops; in a normal climbing game, zero.

The rule: a fixed ruler tells you **how much** progress, but it cannot tell you **going in circles** from **standing still**. For that you need the cross-time tournament.

## Why bother with all three

None of these three is a discovery about nature. They are known hazards, re-derived carefully on our own equipment, and that is the point. We are about to turn this ruler on something we genuinely do not know the answer to: real neural networks, on a real chase, trying to outwit each other. When that experiment gives a surprising number, we need to already trust the ruler, because by then the ground truth is gone and the ruler is all we have.

So: **graded**, **aligned**, and backed by a **cross-time tournament** for cycling. Three rules, three failures we caused on purpose in games where we knew the answer. Now the interesting game can begin. That is the next note.
